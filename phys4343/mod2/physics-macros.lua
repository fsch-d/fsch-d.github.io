-- physics-macros.lua
-- Robust expansion of common "physics" macros into plain TeX that Pandoc understands.
-- Handles nested/braced arguments correctly, and supports 1- and 2-arg shorthands.

-- parse a balanced braced group starting at position `pos` (where s:sub(pos,pos) == "{")
-- returns content (without outer braces) and next position (index after the closing brace),
-- or nil if braces are unbalanced.
local function parse_braced(s, pos)
  if s:sub(pos,pos) ~= "{" then return nil end
  local depth = 0
  local i = pos
  for j = pos, #s do
    local c = s:sub(j,j)
    if c == "{" then
      depth = depth + 1
    elseif c == "}" then
      depth = depth - 1
      if depth == 0 then
        return s:sub(pos+1, j-1), j + 1
      end
    end
  end
  return nil
end

-- Given a math string `s`, replace known macros by expanded TeX (safe for Pandoc->MathML).
local function expand_macros(s)
  local out = {}
  local i = 1
  while i <= #s do
    -- find next backslash + name
    local si, ei, name = s:find("\\([%a]+)", i)
    if not si then
      table.insert(out, s:sub(i))
      break
    end

    -- append text before the macro
    if si > i then
      table.insert(out, s:sub(i, si-1))
    end

    -- decide what to do
    local handler = {
      -- handlers return replacement string when given array of args
      braket = function(args)
        if #args == 1 then
          return "\\left\\langle " .. args[1] .. " \\mid " .. args[1] .. " \\right\\rangle"
        else
          return "\\left\\langle " .. args[1] .. " \\mid " .. args[2] .. " \\right\\rangle"
        end
      end,
      ket = function(args)
        return "\\left\\lvert " .. args[1] .. " \\right\\rangle"
      end,
      bra = function(args)
        return "\\left\\langle " .. args[1] .. " \\right\\rvert"
      end,
      ketbra = function(args)
        if #args == 1 then
          return "\\left\\lvert " .. args[1] .. " \\right\\rangle\\left\\langle " .. args[1] .. " \\right\\rvert"
        else
          return "\\left\\lvert " .. args[1] .. " \\right\\rangle\\left\\langle " .. args[2] .. " \\right\\rvert"
        end
      end,
      mel = function(args)
        return "\\left\\langle " .. args[1] .. " \\mid " .. args[2] .. " \\mid " .. args[3] .. " \\right\\rangle"
      end,
      comm = function(args)
        return "\\left[ " .. args[1] .. " , " .. args[2] .. " \\right]"
      end,
      expval = function(args)
        return "\\left\\langle " .. args[1] .. " \\right\\rangle"
      end
    }

    if not handler[name] then
      -- unknown macro, keep it unchanged
      table.insert(out, s:sub(si, ei))
      i = ei + 1
    else
      -- collect braced arguments (0..3). We allow optional whitespace between macro name and first brace.
      local args = {}
      local pos = ei + 1
      -- skip any spaces
      while pos <= #s and s:sub(pos,pos):match("%s") do pos = pos + 1 end
      -- gather up to 3 braced args (most of our macros use <=3)
      for k = 1, 3 do
        if pos <= #s and s:sub(pos,pos) == "{" then
          local content, nextpos = parse_braced(s, pos)
          if not content then
            -- unbalanced; bail and leave original text verbatim
            table.insert(out, s:sub(si, ei))
            pos = ei + 1
            break
          end
          table.insert(args, content)
          pos = nextpos
          -- skip whitespace before next arg
          while pos <= #s and s:sub(pos,pos):match("%s") do pos = pos + 1 end
        else
          break
        end
      end

      if #args == 0 then
        -- no braced args found; keep original
        table.insert(out, s:sub(si, ei))
        i = ei + 1
      else
        -- call handler and append replacement
        local ok, repl = pcall(handler[name], args)
        if ok and repl then
          table.insert(out, repl)
          i = pos
        else
          -- if handler failed for any reason, fall back to original text
          table.insert(out, s:sub(si, ei))
          i = ei + 1
        end
      end
    end
  end

  return table.concat(out)
end

-- Pandoc filter hook: operate on both inline and display math
function Math(el)
  local s = el.text
  local new = expand_macros(s)
  if new ~= s then
    el.text = new
  end
  return el
end
