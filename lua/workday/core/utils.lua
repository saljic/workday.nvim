-- Core utilities for workday.nvim
local constants = require("workday.core.constants")

local M = {}

-- Safe buffer validation
function M.is_valid_buffer(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

-- Safe window validation  
function M.is_valid_window(win)
  return win and vim.api.nvim_win_is_valid(win)
end

-- Get visual selection range
function M.get_visual_selection()
  local start_row = vim.fn.line("'<") - 1  -- Convert to 0-indexed
  local end_row = vim.fn.line("'>") - 1    -- Convert to 0-indexed
  
  -- Ensure we don't process the header (line 0)
  start_row = math.max(1, start_row)
  end_row = math.max(1, end_row)
  
  return start_row, end_row
end

-- Check if line matches pattern
function M.line_matches(line, pattern_name)
  local pattern = constants.PATTERNS[pattern_name]
  if not pattern then
    error("Unknown pattern: " .. tostring(pattern_name))
  end
  return line and line:match(pattern)
end

-- Check if line has content (non-whitespace)
function M.line_has_content(line)
  return M.line_matches(line, "NON_EMPTY")
end

-- Check if line is a todo (any type)
function M.is_todo_line(line)
  return M.line_matches(line, "TODO_UNCOMPLETED") or 
         M.line_matches(line, "TODO_COMPLETED") or
         M.line_matches(line, "TODO_COMPLETED_UPPER")
end

-- Check if line is completed todo
function M.is_completed_todo(line)
  return M.line_matches(line, "TODO_COMPLETED") or
         M.line_matches(line, "TODO_COMPLETED_UPPER")
end

-- Check if line is uncompleted todo
function M.is_uncompleted_todo(line)
  return M.line_matches(line, "TODO_UNCOMPLETED")
end

-- Check if line is backlog item
function M.is_backlog_line(line)
  return M.line_matches(line, "BACKLOG_ITEM")
end

-- Strip todo prefix from line
function M.strip_todo_prefix(line)
  return line:gsub(constants.PATTERNS.TODO_PREFIX, "")
end

-- Add todo prefix to line
function M.add_todo_prefix(line)
  return "- [ ] " .. line
end

-- Toggle todo completion state
function M.toggle_todo_completion(line)
  if M.is_uncompleted_todo(line) then
    return line:gsub("^%- %[%s%]", "- [x]", 1)
  elseif M.is_completed_todo(line) then
    return line:gsub("^%- %[[xX]%]", "- [ ]", 1)
  end
  return line
end

-- Center text within given width
function M.center_text(text, width)
  local padding = math.max(0, math.floor((width - #text) / 2))
  return string.rep(" ", padding) .. text
end

-- Validate buffer type
function M.is_valid_buffer_type(buffer_type)
  for _, valid_type in pairs(constants.BUFFER_TYPES) do
    if buffer_type == valid_type then
      return true
    end
  end
  return false
end

return M