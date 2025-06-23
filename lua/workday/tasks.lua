local line_utils = require("workday.line_utils")
local highlights = require("workday.highlights")

local M = {}

-- Remove empty lines from buffer (keeping the header) - clean version
local function cleanup_empty_lines(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local cleaned_lines = {}
  
  -- Always keep the header (first line)
  if #lines > 0 then
    table.insert(cleaned_lines, lines[1])
  end
  
  -- Add non-empty lines
  for i = 2, #lines do
    if lines[i] and lines[i]:match("%S") then -- has non-whitespace content
      table.insert(cleaned_lines, lines[i])
    end
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, cleaned_lines)
end

-- Remove empty lines with cursor safety for source buffers
local function cleanup_empty_lines_with_cursor_safety(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local cleaned_lines = {}
  
  -- Always keep the header (first line)
  if #lines > 0 then
    table.insert(cleaned_lines, lines[1])
  end
  
  -- Add non-empty lines
  local has_content = false
  for i = 2, #lines do
    if lines[i] and lines[i]:match("%S") then -- has non-whitespace content
      table.insert(cleaned_lines, lines[i])
      has_content = true
    end
  end
  
  -- If no content, add empty line for cursor positioning to prevent visual flicker
  if not has_content then
    table.insert(cleaned_lines, "")
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, cleaned_lines)
end

-- Ensure buffer has content for cursor positioning (adds empty line if needed)
local function ensure_cursor_line(buf)
  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count == 1 then
    -- Only header exists, add empty line for cursor positioning
    vim.api.nvim_buf_set_lines(buf, 1, 1, false, {""})
  end
end

-- Toggle the checkbox state of a task in the current buffer.
-- Single line version (normal mode).
function M.toggle_todo()
  local buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  
  if row < 1 then return end  -- skip header
  
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  if not line then return end
  
  local toggled = line_utils.toggle_completed(line)
  vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { toggled })
  highlights.apply_buffer_highlights(buf, "todo")
end

-- Toggle multiple todos in visual selection.
function M.toggle_todo_visual()
  local buf = vim.api.nvim_get_current_buf()
  
  -- Get visual selection range
  local start_row = vim.fn.line("'<") - 1  -- Convert to 0-indexed
  local end_row = vim.fn.line("'>") - 1    -- Convert to 0-indexed
  
  -- Ensure we don't process the header (line 0)
  start_row = math.max(1, start_row)
  end_row = math.max(1, end_row)
  
  -- Process each line in the selection
  for row = start_row, end_row do
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    if line and (line:match("^%s*-%s*%[%s%]") or line:match("^%s*-%s*%[x%]") or line:match("^%s*-%s*%[X%]")) then
      local toggled = line_utils.toggle_completed(line)
      vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { toggled })
    end
  end
  
  highlights.apply_buffer_highlights(buf, "todo")
end

-- Move a task from the todo list to the top of the backlog.
function M.move_to_backlog_top(backlog_buf)
  local cur_buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  if row < 1 then return end

  local line = vim.api.nvim_buf_get_lines(cur_buf, row, row + 1, false)[1]
  if not line or line == "" then return end

  vim.api.nvim_buf_set_lines(cur_buf, row, row + 1, false, {})
  local stripped_line = line_utils.strip_prefix(line)

  -- Clean up backlog buffer first, then add the new line
  cleanup_empty_lines(backlog_buf)
  local backlog_lines = vim.api.nvim_buf_get_lines(backlog_buf, 0, -1, false)
  if #backlog_lines == 1 then
    table.insert(backlog_lines, stripped_line)
  else
    table.insert(backlog_lines, 2, stripped_line)
  end
  vim.api.nvim_buf_set_lines(backlog_buf, 0, -1, false, backlog_lines)
  
  -- Position cursor on the newly added line in backlog buffer
  local view_buffers = require("workday").view_buffers
  if view_buffers and view_buffers.backlog_win then
    local backlog_win = view_buffers.backlog_win
    if vim.api.nvim_win_is_valid(backlog_win) then
      vim.api.nvim_win_set_cursor(backlog_win, {2, 0}) -- First content line
    end
  end
  
  cleanup_empty_lines_with_cursor_safety(cur_buf)
  
  -- Ensure cursor is positioned correctly in todo buffer
  if view_buffers and view_buffers.todo_win then
    local todo_win = view_buffers.todo_win
    if vim.api.nvim_win_is_valid(todo_win) then
      vim.api.nvim_win_set_cursor(todo_win, {2, 0})
    end
  end
  
  highlights.apply_buffer_highlights(cur_buf, "todo")
  highlights.apply_buffer_highlights(backlog_buf, "backlog")
end

-- Move multiple tasks from todo to backlog (visual selection).
function M.move_to_backlog_top_visual(backlog_buf)
  local cur_buf = vim.api.nvim_get_current_buf()
  
  -- Get visual selection range
  local start_row = vim.fn.line("'<") - 1  -- Convert to 0-indexed
  local end_row = vim.fn.line("'>") - 1    -- Convert to 0-indexed
  
  -- Ensure we don't process the header (line 0)
  start_row = math.max(1, start_row)
  end_row = math.max(1, end_row)
  
  -- Clean up backlog buffer first
  cleanup_empty_lines(backlog_buf)
  local backlog_lines = vim.api.nvim_buf_get_lines(backlog_buf, 0, -1, false)
  
  -- Move lines one by one (in reverse order to maintain line numbers)
  for row = end_row, start_row, -1 do
    local line = vim.api.nvim_buf_get_lines(cur_buf, row, row + 1, false)[1]
    if line and line ~= "" then
      vim.api.nvim_buf_set_lines(cur_buf, row, row + 1, false, {})
      local stripped_line = line_utils.strip_prefix(line)
      
      -- Insert at position 2 (after header)
      if #backlog_lines == 1 then
        backlog_lines[2] = stripped_line
      else
        -- Shift existing lines down and insert new line at position 2
        for i = #backlog_lines, 2, -1 do
          backlog_lines[i + 1] = backlog_lines[i]
        end
        backlog_lines[2] = stripped_line
      end
    end
  end
  
  vim.api.nvim_buf_set_lines(backlog_buf, 0, -1, false, backlog_lines)
  
  -- Position cursor on first moved line in backlog buffer
  local view_buffers = require("workday").view_buffers
  if view_buffers and view_buffers.backlog_win then
    local backlog_win = view_buffers.backlog_win
    if vim.api.nvim_win_is_valid(backlog_win) then
      vim.api.nvim_win_set_cursor(backlog_win, {2, 0})
    end
  end
  
  cleanup_empty_lines_with_cursor_safety(cur_buf)
  
  -- Ensure cursor is positioned correctly in todo buffer
  if view_buffers and view_buffers.todo_win then
    local todo_win = view_buffers.todo_win
    if vim.api.nvim_win_is_valid(todo_win) then
      vim.api.nvim_win_set_cursor(todo_win, {2, 0})
    end
  end
  
  highlights.apply_buffer_highlights(cur_buf, "todo")
  highlights.apply_buffer_highlights(backlog_buf, "backlog")
end

-- Move a task from the backlog to the bottom of the todo list.
function M.move_to_todo_bottom(from_buf, todo_buf)
  local cur_buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  if cur_buf ~= from_buf then
    vim.notify("This command should only be used in the backlog and archive buffer", vim.log.levels.ERROR)
    return
  end

  if row < 1 then return end

  local line = vim.api.nvim_buf_get_lines(cur_buf, row, row + 1, false)[1]
  if not line or line == "" then return end

  vim.api.nvim_buf_set_lines(cur_buf, row, row + 1, false, {})
  local prefixed_line = line_utils.add_prefix(line)
  
  -- Clean up todo buffer first, then add the new line
  cleanup_empty_lines(todo_buf)
  local todo_line_count = vim.api.nvim_buf_line_count(todo_buf)
  vim.api.nvim_buf_set_lines(todo_buf, todo_line_count, todo_line_count, false, { prefixed_line })
  
  -- Position cursor on the newly added line in todo buffer
  local todo_win = nil
  local view_buffers = require("workday").view_buffers
  if view_buffers then
    todo_win = view_buffers.todo_win
    if todo_win and vim.api.nvim_win_is_valid(todo_win) then
      vim.api.nvim_win_set_cursor(todo_win, {todo_line_count + 1, 0})
    end
  end
  
  -- Determine buffer type for highlighting
  local cur_buf_type = "backlog" -- default
  if view_buffers and cur_buf == view_buffers.archive_buf then
    cur_buf_type = "archive"
  end
  cleanup_empty_lines(cur_buf)
  highlights.apply_buffer_highlights(cur_buf, cur_buf_type)
  highlights.apply_buffer_highlights(todo_buf, "todo")
end

-- Move multiple tasks from backlog/archive to todo (visual selection).
function M.move_to_todo_bottom_visual(from_buf, todo_buf)
  local cur_buf = vim.api.nvim_get_current_buf()

  if cur_buf ~= from_buf then
    vim.notify("This command should only be used in the backlog and archive buffer", vim.log.levels.ERROR)
    return
  end

  -- Get visual selection range
  local start_row = vim.fn.line("'<") - 1  -- Convert to 0-indexed
  local end_row = vim.fn.line("'>") - 1    -- Convert to 0-indexed
  
  -- Ensure we don't process the header (line 0)
  start_row = math.max(1, start_row)
  end_row = math.max(1, end_row)
  
  -- Collect lines to move (in reverse order to maintain line numbers)
  local lines_to_move = {}
  for row = end_row, start_row, -1 do
    local line = vim.api.nvim_buf_get_lines(cur_buf, row, row + 1, false)[1]
    if line and line ~= "" then
      table.insert(lines_to_move, 1, line_utils.add_prefix(line)) -- Insert at beginning to maintain order
      vim.api.nvim_buf_set_lines(cur_buf, row, row + 1, false, {})
    end
  end
  
  -- Clean up todo buffer first
  cleanup_empty_lines(todo_buf)
  local todo_line_count = vim.api.nvim_buf_line_count(todo_buf)
  
  -- Add moved lines to end of todo buffer
  for _, prefixed_line in ipairs(lines_to_move) do
    vim.api.nvim_buf_set_lines(todo_buf, todo_line_count, todo_line_count, false, { prefixed_line })
    todo_line_count = todo_line_count + 1
  end
  
  -- Position cursor on first moved line in todo buffer
  local view_buffers = require("workday").view_buffers
  if view_buffers and view_buffers.todo_win then
    local todo_win = view_buffers.todo_win
    if vim.api.nvim_win_is_valid(todo_win) then
      vim.api.nvim_win_set_cursor(todo_win, {vim.api.nvim_buf_line_count(todo_buf) - #lines_to_move + 1, 0})
    end
  end
  
  -- Determine buffer type for highlighting
  local cur_buf_type = "backlog" -- default
  if view_buffers and cur_buf == view_buffers.archive_buf then
    cur_buf_type = "archive"
  end
  cleanup_empty_lines(cur_buf)
  highlights.apply_buffer_highlights(cur_buf, cur_buf_type)
  highlights.apply_buffer_highlights(todo_buf, "todo")
end

-- Archive tasks marked as completed in the todo list.
function M.archive_completed_tasks()
  local view_buffers = require("workday").view_buffers
  if not view_buffers or not view_buffers.todo_buf or not view_buffers.archive_buf then
    vim.notify("Workday view is not open", vim.log.levels.ERROR)
    return
  end

  local todo_buf = view_buffers.todo_buf
  local archive_buf = view_buffers.archive_buf
  local todo_line_count = vim.api.nvim_buf_line_count(todo_buf)
  local archived_count = 0

  -- Clean up archive buffer first if we're going to add items
  local has_completed_tasks = false
  for i = 2, todo_line_count do
    local line = vim.api.nvim_buf_get_lines(todo_buf, i-1, i, false)[1]
    if line and line:match("^%- %[[xX]%] ") then
      has_completed_tasks = true
      break
    end
  end
  
  if has_completed_tasks then
    cleanup_empty_lines(archive_buf)
  end

  for i = todo_line_count, 2, -1 do  -- iterate from bottom to top (skip header)
    local line = vim.api.nvim_buf_get_lines(todo_buf, i-1, i, false)[1]
    if line and line:match("^%- %[[xX]%] ") then
      local stripped_line = line_utils.strip_prefix(line)
      archived_count = archived_count + 1
      vim.api.nvim_buf_set_lines(todo_buf, i-1, i, false, {})
      vim.api.nvim_buf_set_lines(archive_buf, -1, -1, false, { stripped_line })
    end
  end

  if archived_count > 0 then
    vim.notify("Archived " .. archived_count .. " tasks.")
    cleanup_empty_lines(todo_buf)
    
    -- Position cursor on first content line in archive buffer
    if view_buffers and view_buffers.archive_win then
      local archive_win = view_buffers.archive_win
      if vim.api.nvim_win_is_valid(archive_win) then
        vim.api.nvim_win_set_cursor(archive_win, {2, 0}) -- First content line
      end
    end
    
    highlights.apply_buffer_highlights(todo_buf, "todo")
    highlights.apply_buffer_highlights(archive_buf, "archive")
  else
    vim.notify("No completed tasks found to archive.")
  end
end

return M
