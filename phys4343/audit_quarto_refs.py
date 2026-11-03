#!/usr/bin/env python3
"""Audit rendered Quarto links and source-text section references.
Run from the Quarto project root after `quarto render`.
"""
from pathlib import Path
from urllib.parse import urlsplit, unquote
from bs4 import BeautifulSoup
import argparse
import re

SKIP_DIRS = {'.ipynb_checkpoints', '.numbering-backup', '.git', '_site', '.quarto'}
TEXT_REF = re.compile(r'\b(?:sections?|subsections?|chapters?)\s+\d+(?:\.\d+)*(?:\s*(?:and|to|[-–])\s*\d+(?:\.\d+)*)?', re.I)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--site', default='_site', help='Rendered site directory')
    ap.add_argument('--output', default='reference-audit.txt')
    args = ap.parse_args()
    root = Path.cwd().resolve()
    site = (root / args.site).resolve()
    if not site.is_dir():
        ap.error(f'{site} does not exist; run quarto render first')
    pages = sorted(site.rglob('*.html'))
    ids = {}
    for page in pages:
        soup = BeautifulSoup(page.read_text(encoding='utf-8', errors='replace'), 'html.parser')
        ids[page] = {tag.get('id') for tag in soup.find_all(id=True)} | {tag.get('name') for tag in soup.find_all('a', attrs={'name': True})}
    broken = []
    checked = 0
    for page in pages:
        soup = BeautifulSoup(page.read_text(encoding='utf-8', errors='replace'), 'html.parser')
        for a in soup.find_all('a', href=True):
            href = a['href'].strip()
            parsed = urlsplit(href)
            if parsed.scheme or parsed.netloc or href.startswith('//') or not href:
                continue
            if not parsed.path and not parsed.fragment:
                continue
            target = (page.parent / unquote(parsed.path)).resolve() if parsed.path else page
            if parsed.path.endswith('/') or (target.exists() and target.is_dir()):
                target = target / 'index.html'
            if not target.is_relative_to(site):
                continue
            checked += 1
            label = a.get_text(' ', strip=True)[:70]
            loc = str(page.relative_to(site))
            if not target.is_file():
                broken.append((loc, href, 'missing target file', label))
            elif parsed.fragment and target.suffix.lower() in ('.html', '.htm'):
                fragment = unquote(parsed.fragment)
                if target not in ids:
                    bs = BeautifulSoup(target.read_text(encoding='utf-8', errors='replace'), 'html.parser')
                    ids[target] = {t.get('id') for t in bs.find_all(id=True)} | {t.get('name') for t in bs.find_all('a', attrs={'name': True})}
                if fragment not in ids[target]:
                    broken.append((loc, href, 'missing subsection anchor', label))
    candidates = []
    for qmd in sorted(root.rglob('*.qmd')):
        if any(part in SKIP_DIRS or part.startswith('.') for part in qmd.relative_to(root).parts):
            continue
        in_fence = False
        fence_char, fence_len = '', 0
        for n, line in enumerate(qmd.read_text(encoding='utf-8', errors='replace').splitlines(), 1):
            fence = re.match(r'^\s*(`{3,}|~{3,})', line)
            if fence:
                token = fence.group(1)
                if not in_fence:
                    in_fence, fence_char, fence_len = True, token[0], len(token)
                elif token[0] == fence_char and len(token) >= fence_len:
                    in_fence = False
                continue
            if in_fence or re.match(r'^\s*#{1,6}\s', line):
                continue
            if TEXT_REF.search(line):
                candidates.append((str(qmd.relative_to(root)), n, line.strip()[:240]))
    out = [f'QUARTO REFERENCE AUDIT\nRendered HTML pages: {len(pages)}\nLocal links checked: {checked}\nBroken links/anchors: {len(broken)}\nText-reference candidates: {len(candidates)}\n',
           '\n=== BROKEN LOCAL LINKS / ANCHORS ===\n']
    if not broken:
        out.append('None found.\n')
    for source, href, reason, label in broken:
        out.append(f'{source}\n  -> {href}\n  {reason}' + (f' | link text: {label}' if label else '') + '\n')
    out.append('\n=== TEXT REFERENCES TO REVIEW (NOT AUTOMATICALLY BROKEN) ===\n')
    if not candidates:
        out.append('None found.\n')
    for path, n, line in candidates:
        out.append(f'{path}:{n}: {line}\n')
    Path(args.output).write_text('\n'.join(out), encoding='utf-8')
    print(f'HTML pages: {len(pages)} | Local links: {checked} | Broken: {len(broken)} | Text references to review: {len(candidates)}')
    print(f'Report: {args.output}')
    if broken:
        print('\nFirst broken links:')
        for source, href, reason, _ in broken[:10]:
            print(f'  {source} -> {href} ({reason})')

if __name__ == '__main__':
    main()
