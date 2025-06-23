-- Refactored tasks module using new abstractions
local constants = require("workday.core.constants")
local utils = require("workday.core.utils")
local BufferManager = require("workday.core.buffer_manager")
local TaskOperations = require("workday.core.task_operations")

local M = {}

-- Initialize with view buffers
function M.init(view_buffers)
  M.buffer_manager = BufferManager:new(view_buffers)
  M.buffer_manager.setup_highlight_groups()
end

-- Toggle todo completion (single line or visual selection)
function M.toggle_todo()
  if not M.buffer_manager or not M.buffer_manager:is_valid_state() then
    vim.notify("Workday view is not properly initialized", vim.log.levels.ERROR)
    return
  end
  
  local mode = vim.fn.mode()
  
  if mode == 'v' or mode == 'V' or mode == '\22' then
    -- Visual mode: toggle multiple lines
    M.toggle_todo_visual()
  else
    -- Normal mode: toggle single line
    M.toggle_todo_single()
  end
end

-- Toggle single todo at cursor
function M.toggle_todo_single()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  
  if row < 1 then return end  -- Skip header
  
  local lines = M.buffer_manager:get_lines(constants.BUFFER_TYPES.TODO)
  if row >= #lines then return end
  
  local line = lines[row + 1]  -- Convert to 1-indexed
  if not line then return end
  
  local toggled_line = TaskOperations.toggle_task_completion(line)
  lines[row + 1] = toggled_line
  
  M.buffer_manager:set_lines(constants.BUFFER_TYPES.TODO, 0, -1, lines)
  M.buffer_manager:apply_highlights(constants.BUFFER_TYPES.TODO)
end

-- Toggle multiple todos in visual selection
function M.toggle_todo_visual()
  local start_row, end_row = utils.get_visual_selection()
  
  local lines = M.buffer_manager:get_lines(constants.BUFFER_TYPES.TODO)
  
  -- Process each line in the selection
  for row = start_row, end_row do
    if row < #lines then
      local line = lines[row + 1]  -- Convert to 1-indexed
      if utils.is_todo_line(line) then
        lines[row + 1] = TaskOperations.toggle_task_completion(line)
      end
    end
  end
  
  M.buffer_manager:set_lines(constants.BUFFER_TYPES.TODO, 0, -1, lines)
  M.buffer_manager:apply_highlights(constants.BUFFER_TYPES.TODO)
end

-- Move task(s) from todo to backlog
function M.move_to_backlog_top(backlog_buf)
  M._execute_move_operation(
    constants.BUFFER_TYPES.TODO,
    constants.BUFFER_TYPES.BACKLOG,
    constants.POSITIONS.TOP,
    false -- single line
  )
end

-- Move multiple tasks from todo to backlog (visual selection)
function M.move_to_backlog_top_visual(backlog_buf)
  M._execute_move_operation(
    constants.BUFFER_TYPES.TODO,
    constants.BUFFER_TYPES.BACKLOG,
    constants.POSITIONS.TOP,
    true -- visual selection
  )
end

-- Move task(s) from backlog/archive to todo
function M.move_to_todo_bottom(from_buf, todo_buf)
  -- Determine source buffer type
  local source_type = nil
  if from_buf == M.buffer_manager:get_buffer(constants.BUFFER_TYPES.BACKLOG) then
    source_type = constants.BUFFER_TYPES.BACKLOG
  elseif from_buf == M.buffer_manager:get_buffer(constants.BUFFER_TYPES.ARCHIVE) then
    source_type = constants.BUFFER_TYPES.ARCHIVE
  else
    vim.notify("Invalid source buffer", vim.log.levels.ERROR)
    return
  end
  
  M._execute_move_operation(
    source_type,
    constants.BUFFER_TYPES.TODO,
    constants.POSITIONS.BOTTOM,
    false -- single line
  )
end

-- Move multiple tasks from backlog/archive to todo (visual selection)
function M.move_to_todo_bottom_visual(from_buf, todo_buf)
  -- Determine source buffer type
  local source_type = nil
  if from_buf == M.buffer_manager:get_buffer(constants.BUFFER_TYPES.BACKLOG) then
    source_type = constants.BUFFER_TYPES.BACKLOG
  elseif from_buf == M.buffer_manager:get_buffer(constants.BUFFER_TYPES.ARCHIVE) then
    source_type = constants.BUFFER_TYPES.ARCHIVE
  else
    vim.notify("Invalid source buffer", vim.log.levels.ERROR)
    return
  end
  
  M._execute_move_operation(
    source_type,
    constants.BUFFER_TYPES.TODO,
    constants.POSITIONS.BOTTOM,
    true -- visual selection
  )
end

-- Archive completed tasks
function M.archive_completed_tasks()
  local todo_lines = M.buffer_manager:get_lines(constants.BUFFER_TYPES.TODO)
  local archive_lines = M.buffer_manager:get_lines(constants.BUFFER_TYPES.ARCHIVE)
  
  -- Find completed tasks
  local completed_tasks = TaskOperations.find_completed_tasks(todo_lines)
  
  if #completed_tasks == 0 then
    vim.notify("No completed tasks found to archive.", vim.log.levels.INFO)
    return
  end
  
  -- Create move result
  local result = TaskOperations.create_move_result(
    todo_lines,
    archive_lines,
    completed_tasks,
    constants.BUFFER_TYPES.ARCHIVE,
    constants.POSITIONS.BOTTOM
  )
  
  -- Apply changes
  M.buffer_manager:set_lines(constants.BUFFER_TYPES.TODO, 0, -1, result.source_lines)
  M.buffer_manager:set_lines(constants.BUFFER_TYPES.ARCHIVE, 0, -1, result.destination_lines)
  
  -- Cleanup and positioning
  M.buffer_manager:cleanup_empty_lines(constants.BUFFER_TYPES.TODO, true)
  M.buffer_manager:position_cursor(constants.BUFFER_TYPES.ARCHIVE, 2, 0)
  
  -- Apply highlights
  M.buffer_manager:apply_highlights(constants.BUFFER_TYPES.TODO)
  M.buffer_manager:apply_highlights(constants.BUFFER_TYPES.ARCHIVE)
  
  vim.notify("Archived " .. result.moved_tasks_count .. " tasks.", vim.log.levels.INFO)
end

-- Execute move operation (internal helper)
function M._execute_move_operation(source_type, destination_type, position, is_visual)
  if not M.buffer_manager or not M.buffer_manager:is_valid_state() then
    vim.notify("Workday view is not properly initialized", vim.log.levels.ERROR)
    return
  end
  
  local source_lines = M.buffer_manager:get_lines(source_type)
  local destination_lines = M.buffer_manager:get_lines(destination_type)
  
  local start_row, end_row
  
  if is_visual then
    start_row, end_row = utils.get_visual_selection()
  else
    -- Single line at cursor
    local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
    if cursor_row < 1 then return end  -- Skip header
    start_row, end_row = cursor_row, cursor_row
  end
  
  -- Extract tasks to move
  local tasks = TaskOperations.extract_tasks_from_lines(source_lines, start_row + 1, end_row + 1)
  
  if #tasks == 0 then
    vim.notify("No tasks to move", vim.log.levels.INFO)
    return
  end
  
  -- Create move result
  local result = TaskOperations.create_move_result(
    source_lines,
    destination_lines,
    tasks,
    destination_type,
    position
  )
  
  -- Apply changes
  M.buffer_manager:set_lines(source_type, 0, -1, result.source_lines)
  M.buffer_manager:set_lines(destination_type, 0, -1, result.destination_lines)
  
  -- Cleanup and cursor positioning
  local source_has_content = M.buffer_manager:cleanup_empty_lines(source_type, false)
  M.buffer_manager:cleanup_empty_lines(destination_type, false)
  
  -- Ensure cursor safety for source buffer if it becomes empty
  if not source_has_content then
    M.buffer_manager:ensure_cursor_line(source_type)
    M.buffer_manager:position_cursor(source_type, 2, 0)
  end
  
  -- Position cursor in destination
  local dest_cursor_row = position == constants.POSITIONS.TOP and 2 or (#result.destination_lines - #tasks + 1)
  M.buffer_manager:position_cursor(destination_type, dest_cursor_row, 0)
  
  -- Apply highlights
  M.buffer_manager:apply_highlights(source_type)
  M.buffer_manager:apply_highlights(destination_type)
end

return M