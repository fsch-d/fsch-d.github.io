#!/usr/bin/env python3
"""Synchronize website chapter/page numbering from Quarto sidebar order.

Usage: python3 number_quarto.py [--number-headings] [--apply]
Without --apply, prints a preview. With --apply, writes backups and updates files.
"""
from pathlib import Path
import argparse
import re
import shutil
import sys
import yaml

ROOT = Path.cwd()
CONFIG = ROOT / '_quarto.yml'
PREFIX = re.compile(r'^\d+(?:\.\d+)*\s+[—–-]?\s*')
FRONT = re.compile(r'\A(---\s*\n)(.*?)(\n---\s*\n)', re.S)
TITLE_LINE = re.compile(r'(?m)^(title:\s*)(.*)$')

def clean(s):
    return PREFIX.sub('', str(s)).strip()

def title_from_page(path):
    source = path.read_text(encoding='utf-8')
    m = FRONT.match(source)
    if not m:
        raise ValueError(f'Missing YAML front matter: {path}')
    metadata = yaml.safe_load(m.group(2)) or {}
    return clean(metadata.get('title') or path.stem.replace('-', ' ').title())

def change_title(path, numbered_title):
    source = path.read_text(encoding='utf-8')
    m = FRONT.match(source)
    if not m:
        raise ValueError(f'Missing YAML front matter: {path}')
    body = m.group(2)
    new_line = 'title: ' + yaml.safe_dump(numbered_title, allow_unicode=True, default_flow_style=True).strip()
    if TITLE_LINE.search(body):
        body = TITLE_LINE.sub(lambda _: new_line, body, count=1)
    else:
        body = new_line + '\n' + body
    return m.group(1) + body + m.group(3) + source[m.end():]

def change_headings(source, page_number):
    """Prefix already-numbered Markdown headings; leave all others unchanged.

    Skips fenced code and fenced divs (including callouts), where headings
    may have a different structural meaning. Re-running is idempotent.
    """
    lines = source.splitlines(keepends=True)
    out = []
    fence = None
    div_depth = 0
    heading = re.compile(r'^(#{1,6})[ \t]+(\d+(?:\.\d+)*)(\.?)([ \t]+)(.*)$')
    code_open = re.compile(r'^ {0,3}(`{3,}|~{3,})')
    div_fence = re.compile(r'^ {0,3}(:{3,})(?:\s|$)')
    for line in lines:
        stripped = line.rstrip('\r\n')
        cm = code_open.match(stripped)
        if fence:
            if cm and cm.group(1)[0] == fence[0] and len(cm.group(1)) >= len(fence):
                fence = None
            out.append(line)
            continue
        if cm:
            fence = cm.group(1)
            out.append(line)
            continue
        dm = div_fence.match(stripped)
        if dm:
            # A bare ::: closes the innermost div; ::: {attributes} opens one.
            if stripped.strip().rstrip(':').strip() == '':
                div_depth = max(0, div_depth - 1)
            else:
                div_depth += 1
            out.append(line)
            continue
        if div_depth:
            out.append(line)
            continue
        m = heading.match(stripped)
        if not m:
            out.append(line)
            continue
        hashes, old_number, punctuation, space, rest = m.groups()
        # Already globally numbered on a previous run: remove this page prefix.
        if old_number.startswith(page_number + '.'):
            local = old_number[len(page_number) + 1:]
        else:
            local = old_number
        new_number = page_number + '.' + local
        newline = line[len(stripped):]
        out.append(f'{hashes} {new_number}{punctuation}{space}{rest}{newline}')
    return ''.join(out)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Write changes after preview')
    parser.add_argument('--number-headings', action='store_true', help='Also prefix manually numbered headings on topic pages')
    args = parser.parse_args()
    if not CONFIG.is_file():
        sys.exit('Run from the Quarto project directory containing _quarto.yml')
    conf = yaml.safe_load(CONFIG.read_text(encoding='utf-8'))
    entries = conf['website']['sidebar']['contents']
    updated = {}
    chapter = 0
    changes = []

    for pos, entry in enumerate(entries):
        if isinstance(entry, str):
            continue
        if not isinstance(entry, dict):
            continue
        href = entry.get('href')
        # Only module overview pages are chapters. Home and other entries remain unnumbered.
        if not (isinstance(href, str) and re.fullmatch(r'mod\d+/index\.qmd', href)):
            continue
        chapter += 1
        page = ROOT / href
        if not page.is_file():
            sys.exit(f'Cannot find {href}')
        title = title_from_page(page)
        # Preserve sidebar wording when it differs from the page title.
        sidebar_title = clean(entry.get('section') or entry.get('text') or title)
        entry['text' if 'text' in entry else 'section'] = f'{chapter} {sidebar_title}'
        updated[page] = change_title(page, f'{chapter} {title}')
        changes.append((href, f'{chapter} {title}'))
        for index, item in enumerate(entry.get('contents', []), 1):
            if isinstance(item, str):
                sub_href = item
                sub_entry = {'href': item}
                entry['contents'][index - 1] = sub_entry
            elif isinstance(item, dict):
                sub_entry = item
                sub_href = item.get('href')
            else:
                continue
            if not isinstance(sub_href, str) or not sub_href.endswith('.qmd'):
                continue
            sub_page = ROOT / sub_href
            if not sub_page.is_file():
                sys.exit(f'Cannot find {sub_href}')
            sub_title = title_from_page(sub_page)
            label = clean(sub_entry.get('text') or sub_title)
            sub_entry['text'] = f'{chapter}.{index} {label}'
            new_source = change_title(sub_page, f'{chapter}.{index} {sub_title}')
            if args.number_headings:
                new_source = change_headings(new_source, f'{chapter}.{index}')
            updated[sub_page] = new_source
            changes.append((sub_href, f'{chapter}.{index} {sub_title}'))

    if not changes:
        sys.exit('No modN/index.qmd chapters found in website.sidebar.contents')
    for path, title in changes:
        print(f'{path:<32} {title}')
    print(f'\n{len(changes)} page titles and sidebar labels identified.')
    if args.number_headings:
        print('Also updating existing manually numbered headings on topic pages (not callouts/code).')
    if not args.apply:
        print('Preview only. Run with --apply to make changes. Note: heading changes are not shown line-by-line.')
        return

    # Backup the ORIGINAL state once. Subsequent runs do not overwrite backups.
    backup = ROOT / '.numbering-backup'
    if backup.exists():
        print(f'Backup directory already exists: {backup}; keeping its contents unchanged.')
    else:
        backup.mkdir()
    paths = [CONFIG, *updated]
    for path in paths:
        target = backup / path.relative_to(ROOT)
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
    for path, content in updated.items():
        path.write_text(content, encoding='utf-8')
    # PyYAML rewrites formatting/comments in _quarto.yml; the original is backed up.
    CONFIG.write_text(yaml.safe_dump(conf, sort_keys=False, allow_unicode=True, width=110), encoding='utf-8')
    print(f'Updated {len(updated)} .qmd files and _quarto.yml. Originals in {backup.relative_to(ROOT)}/')
    print('Run: quarto render')

if __name__ == '__main__':
    main()
