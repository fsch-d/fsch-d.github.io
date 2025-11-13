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
          return "\\left\\langle " .. args[1] .. " \\middle| " .. args[1] .. " \\right\\rangle"
        else
          return "\\left\\langle " .. args[1] .. " \\middle| " .. args[2] .. " \\right\\rangle"
        end
      end,
      ket = function(args)
        return "\\left\\lvert " .. args[1] .. " \\right\\rangle"
      end,
      bra = function(args)
        return "\\left\\langle " .. args[1] .. " \\right\\rvert"
      end,
      ketbra = function(args)
        local space = "\\!\\!"  -- or "\\mkern-3mu" for finer control
        if #args == 1 then
          return "\\left\\lvert " .. args[1] .. " \\right\\rangle" .. space .. "\\left\\langle " .. args[1] .. " \\right\\rvert"
        else
          return "\\left\\lvert " .. args[1] .. " \\right\\rangle" .. space .. "\\left\\langle " .. args[2] .. " \\right\\rvert"
        end
      end,
      mel = function(args)
         return string.format("\\left\\langle %s \\middle| %s \\middle| %s \\right\\rangle", 
                       args[1], args[2], args[3])
      end,
      comm = function(args)
        return "\\left[ " .. args[1] .. " , " .. args[2] .. " \\right]"
      end,
      expval = function(args)
        return "\\left\\langle " .. args[1] .. " \\right\\rangle"
      end,

        -- Quantity command: \qty{value}{unit}
-- Example: \qty{5}{m/s} -> 5\,\text{m/s}
-- Quantity command with optional parentheses
-- \qty{value}{unit} -> value\,unit
-- \qty[]{value}{unit} -> (value)\,unit
-- \qty[()]{value}{unit} -> (value)\,unit
-- \qty[[]]{value}{unit} -> [value]\,unit
-- \qty[{}]{value}{unit} -> {value}\,unit
qty = function(args)
  if #args == 2 then
    -- No brackets: \qty{value}{unit}
    return args[1] .. "\\," .. "\\text{" .. args[2] .. "}"
  elseif #args == 3 then
    -- With brackets: \qty[type]{value}{unit}
    local bracket_type = args[1]
    local value = args[2]
    local unit = args[3]
    
    local left_bracket, right_bracket
    
    if bracket_type == "" or bracket_type == "()" then
      left_bracket = "("
      right_bracket = ")"
    elseif bracket_type == "[]" then
      left_bracket = "["
      right_bracket = "]"
    elseif bracket_type == "{}" then
      left_bracket = "\\{"
      right_bracket = "\\}"
    else
      -- Default to parentheses for unknown types
      left_bracket = "("
      right_bracket = ")"
    end
    
    return left_bracket .. value .. right_bracket .. "\\," .. "\\text{" .. unit .. "}"
  else
    return "\\text{[qty: invalid args]}"
  end
end,

-- Partial derivative: \pdv{f}{x} or \pdv[n]{f}{x} or \pdv{f}{x}{y}
-- Examples:
-- \pdv{f}{x} -> \frac{\partial f}{\partial x}
-- \pdv[2]{f}{x} -> \frac{\partial^2 f}{\partial x^2}
-- \pdv{f}{x}{y} -> \frac{\partial^2 f}{\partial x \partial y}
pdv = function(args)
  if #args == 1 then
    -- \pdv{t}
    return "\\frac{\\partial}{\\partial " .. args[1] .. "}"
  elseif #args == 2 then
    -- \pdv{f}{x}
    return "\\frac{\\partial " .. args[1] .. "}{\\partial " .. args[2] .. "}"
  elseif #args == 3 then
    -- Check if first arg is a number (order) or a variable (mixed partial)
    local first = args[1]
    if tonumber(first) then
      -- \pdv[n]{f}{x} -> \frac{\partial^n f}{\partial x^n}
      local order = first
      return "\\frac{\\partial^{" .. order .. "} " .. args[2] .. "}{\\partial " .. args[3] .. "^{" .. order .. "}}"
    else
      -- \pdv{f}{x}{y} -> \frac{\partial^2 f}{\partial x \partial y}
      return "\\frac{\\partial^2 " .. first .. "}{\\partial " .. args[2] .. " \\partial " .. args[3] .. "}"
    end
  elseif #args == 4 then
    -- \pdv[n]{f}{x}{y} with explicit order (less common)
    local order = args[1]
    return "\\frac{\\partial^{" .. order .. "} " .. args[2] .. "}{\\partial " .. args[3] .. " \\partial " .. args[4] .. "}"
  else
    return "\\text{[pdv: invalid args]}"
  end
end,
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
