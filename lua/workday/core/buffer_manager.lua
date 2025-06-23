-- Centralized buffer management for workday.nvim
local constants = require("workday.core.constants")
local utils = require("workday.core.utils")

local BufferManager = {}
BufferManager.__index = BufferManager

-- Create new BufferManager instance
function BufferManager:new(view_buffers)
  local obj = {
    view_buffers = view_buffers or {},
    highlight_ns = vim.api.nvim_create_namespace(constants.HIGHLIGHT_NAMESPACE)
  }
  setmetatable(obj, self)
  return obj
end

-- Get buffer by type
function BufferManager:get_buffer(buffer_type)
  if not utils.is_valid_buffer_type(buffer_type) then
    error("Invalid buffer type: " .. tostring(buffer_type))
  end
  
  local buffer_key = buffer_type .. "_buf"
  return self.view_buffers[buffer_key]
end

-- Get window by type
function BufferManager:get_window(buffer_type)
  if not utils.is_valid_buffer_type(buffer_type) then
    error("Invalid buffer type: " .. tostring(buffer_type))
  end
  
  local window_key = buffer_type .. "_win"
  return self.view_buffers[window_key]
end

-- Get buffer lines
function BufferManager:get_lines(buffer_type, start_line, end_line)
  local buf = self:get_buffer(buffer_type)
  if not utils.is_valid_buffer(buf) then
    return {}
  end
  
  start_line = start_line or 0
  end_line = end_line or -1
  
  return vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
end

-- Set buffer lines
function BufferManager:set_lines(buffer_type, start_line, end_line, lines)
  local buf = self:get_buffer(buffer_type)
  if not utils.is_valid_buffer(buf) then
    return false
  end
  
  start_line = start_line or 0
  end_line = end_line or -1
  lines = lines or {}
  
  vim.api.nvim_buf_set_lines(buf, start_line, end_line, false, lines)
  return true
end

-- Clean empty lines from buffer
function BufferManager:cleanup_empty_lines(buffer_type, preserve_cursor_line)
  preserve_cursor_line = preserve_cursor_line or false
  
  local lines = self:get_lines(buffer_type)
  local cleaned_lines = {}
  
  -- Always keep the header (first line)
  if #lines > 0 then
    table.insert(cleaned_lines, lines[1])
  end
  
  -- Add non-empty lines
  local has_content = false
  for i = 2, #lines do
    if utils.line_has_content(lines[i]) then
      table.insert(cleaned_lines, lines[i])
      has_content = true
    end
  end
  
  -- If no content and preserve_cursor_line is true, add empty line for cursor positioning
  if not has_content and preserve_cursor_line then
    table.insert(cleaned_lines, "")
  end
  
  self:set_lines(buffer_type, 0, -1, cleaned_lines)
  return has_content
end

-- Ensure cursor line exists for positioning
function BufferManager:ensure_cursor_line(buffer_type)
  local buf = self:get_buffer(buffer_type)
  if not utils.is_valid_buffer(buf) then
    return false
  end
  
  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count == 1 then
    -- Only header exists, add empty line for cursor positioning
    self:set_lines(buffer_type, 1, 1, {""})
    return true
  end
  return false
end

-- Position cursor safely
function BufferManager:position_cursor(buffer_type, row, col)
  local win = self:get_window(buffer_type)
  if not utils.is_valid_window(win) then
    return false
  end
  
  row = row or 2  -- Default to line 2 (first content line)
  col = col or 0
  
  -- Ensure the line exists
  local buf = self:get_buffer(buffer_type)
  if utils.is_valid_buffer(buf) then
    local line_count = vim.api.nvim_buf_line_count(buf)
    if row > line_count then
      -- Add empty line if needed
      self:ensure_cursor_line(buffer_type)
    end
  end
  
  vim.api.nvim_win_set_cursor(win, {row, col})
  return true
end

-- Apply highlights to buffer
function BufferManager:apply_highlights(buffer_type)
  local buf = self:get_buffer(buffer_type)
  if not utils.is_valid_buffer(buf) then
    return false
  end
  
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(buf, self.highlight_ns, 0, -1)
  
  local lines = self:get_lines(buffer_type)
  
  for i, line in ipairs(lines) do
    local line_num = i - 1 -- 0-indexed for extmarks
    local hl_group = nil
    
    -- Always highlight the header (first line)
    if i == 1 then
      hl_group = constants.HIGHLIGHT_GROUPS.HEADER
    elseif buffer_type == constants.BUFFER_TYPES.TODO then
      if utils.is_completed_todo(line) then
        hl_group = constants.HIGHLIGHT_GROUPS.COMPLETED
      elseif utils.is_uncompleted_todo(line) then
        hl_group = constants.HIGHLIGHT_GROUPS.TODO
      end
    elseif buffer_type == constants.BUFFER_TYPES.BACKLOG then
      if utils.is_backlog_line(line) then
        hl_group = constants.HIGHLIGHT_GROUPS.BACKLOG
      end
    elseif buffer_type == constants.BUFFER_TYPES.ARCHIVE then
      -- Archive items (treat as completed)
      hl_group = constants.HIGHLIGHT_GROUPS.COMPLETED
    end
    
    -- Apply highlight using extmarks if we have a highlight group
    if hl_group then
      vim.api.nvim_buf_set_extmark(buf, self.highlight_ns, line_num, 0, {
        end_line = line_num,
        end_col = #line,
        hl_group = hl_group,
        priority = 100
      })
    end
  end
  
  return true
end

-- Setup highlight groups
function BufferManager.setup_highlight_groups()
  for group, opts in pairs(constants.DEFAULT_HIGHLIGHTS) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

-- Refresh all highlights
function BufferManager:refresh_all_highlights()
  self.setup_highlight_groups()
  
  for _, buffer_type in pairs(constants.BUFFER_TYPES) do
    self:apply_highlights(buffer_type)
  end
end

-- Validate buffer state
function BufferManager:is_valid_state()
  for _, buffer_type in pairs(constants.BUFFER_TYPES) do
    local buf = self:get_buffer(buffer_type)
    local win = self:get_window(buffer_type)
    
    if not utils.is_valid_buffer(buf) or not utils.is_valid_window(win) then
      return false
    end
  end
  return true
end

return BufferManager