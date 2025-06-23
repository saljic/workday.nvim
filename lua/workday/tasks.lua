-- Command-based tasks module using Command Pattern
local constants = require("workday.core.constants")
local utils = require("workday.core.utils")
local BufferManager = require("workday.core.buffer_manager")
local CommandExecutor = require("workday.core.command").CommandExecutor

-- Command classes
local ToggleTodoCommand = require("workday.commands.toggle_todo")
local MoveTaskCommand = require("workday.commands.move_task")
local ArchiveCompletedCommand = require("workday.commands.archive_completed")

local M = {}

-- Initialize with view buffers
function M.init(view_buffers)
  M.buffer_manager = BufferManager:new(view_buffers)
  M.buffer_manager.setup_highlight_groups()
  M.command_executor = CommandExecutor:new(M.buffer_manager)
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
  
  -- Create and execute command
  local command = ToggleTodoCommand:new(
    M.buffer_manager,
    constants.BUFFER_TYPES.TODO,
    row + 1,
    line
  )
  
  local success, error_msg = M.command_executor:execute(command)
  if not success then
    vim.notify("Failed to toggle todo: " .. (error_msg or "unknown error"), vim.log.levels.ERROR)
  end
end

-- Toggle multiple todos in visual selection
function M.toggle_todo_visual()
  local start_row, end_row = utils.get_visual_selection()
  
  local lines = M.buffer_manager:get_lines(constants.BUFFER_TYPES.TODO)
  
  -- Create commands for each todo line in selection
  local commands = {}
  for row = start_row, end_row do
    if row < #lines then
      local line = lines[row + 1]  -- Convert to 1-indexed
      if utils.is_todo_line(line) then
        local command = ToggleTodoCommand:new(
          M.buffer_manager,
          constants.BUFFER_TYPES.TODO,
          row + 1,
          line
        )
        table.insert(commands, command)
      end
    end
  end
  
  -- Execute all commands
  for _, command in ipairs(commands) do
    local success, error_msg = M.command_executor:execute(command)
    if not success then
      vim.notify("Failed to toggle todo: " .. (error_msg or "unknown error"), vim.log.levels.ERROR)
      break
    end
  end
  
  -- Exit visual mode
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
end

-- Move task(s) from todo to backlog
function M.move_to_backlog_top(backlog_buf)
  M._execute_move_command(
    constants.BUFFER_TYPES.TODO,
    constants.BUFFER_TYPES.BACKLOG,
    "top",
    false -- single line
  )
end

-- Move multiple tasks from todo to backlog (visual selection)
function M.move_to_backlog_top_visual(backlog_buf)
  M._execute_move_command(
    constants.BUFFER_TYPES.TODO,
    constants.BUFFER_TYPES.BACKLOG,
    "top",
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
  
  M._execute_move_command(
    source_type,
    constants.BUFFER_TYPES.TODO,
    "bottom",
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
  
  M._execute_move_command(
    source_type,
    constants.BUFFER_TYPES.TODO,
    "bottom",
    true -- visual selection
  )
end

-- Archive completed tasks
function M.archive_completed_tasks()
  local command = ArchiveCompletedCommand:new(M.buffer_manager)
  
  local success, error_msg = M.command_executor:execute(command)
  if not success then
    vim.notify("Failed to archive completed tasks: " .. (error_msg or "unknown error"), vim.log.levels.ERROR)
  else
    vim.notify(command:get_description(), vim.log.levels.INFO)
  end
end

-- Execute move command (internal helper)
function M._execute_move_command(source_type, destination_type, position, is_visual)
  if not M.buffer_manager or not M.buffer_manager:is_valid_state() then
    vim.notify("Workday view is not properly initialized", vim.log.levels.ERROR)
    return
  end
  
  local line_numbers = {}
  
  if is_visual then
    local start_row, end_row = utils.get_visual_selection()
    for row = start_row, end_row do
      if row >= 1 then  -- Skip header
        table.insert(line_numbers, row + 1) -- Convert to 1-indexed
      end
    end
  else
    -- Single line at cursor
    local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
    if cursor_row < 1 then return end  -- Skip header
    table.insert(line_numbers, cursor_row + 1) -- Convert to 1-indexed
  end
  
  if #line_numbers == 0 then
    vim.notify("No tasks to move", vim.log.levels.INFO)
    return
  end
  
  -- Create and execute move command
  local command = MoveTaskCommand:new(
    M.buffer_manager,
    source_type,
    destination_type,
    line_numbers,
    position
  )
  
  local success, error_msg = M.command_executor:execute(command)
  if not success then
    vim.notify("Failed to move task: " .. (error_msg or "unknown error"), vim.log.levels.ERROR)
  else
    if is_visual then
      -- Exit visual mode
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
    end
  end
end

-- Undo last command
function M.undo()
  if not M.command_executor then
    vim.notify("Command executor not initialized", vim.log.levels.ERROR)
    return
  end
  
  local success, error_msg = M.command_executor:undo()
  if not success then
    vim.notify("Cannot undo: " .. (error_msg or "nothing to undo"), vim.log.levels.INFO)
  else
    vim.notify("Undid last action", vim.log.levels.INFO)
  end
end

-- Redo last undone command
function M.redo()
  if not M.command_executor then
    vim.notify("Command executor not initialized", vim.log.levels.ERROR)
    return
  end
  
  local success, error_msg = M.command_executor:redo()
  if not success then
    vim.notify("Cannot redo: " .. (error_msg or "nothing to redo"), vim.log.levels.INFO)
  else
    vim.notify("Redid last action", vim.log.levels.INFO)
  end
end

-- Show command history
function M.show_history()
  if not M.command_executor then
    vim.notify("Command executor not initialized", vim.log.levels.ERROR)
    return
  end
  
  local history = M.command_executor:get_history()
  if #history == 0 then
    vim.notify("No command history", vim.log.levels.INFO)
    return
  end
  
  vim.notify("Command History:", vim.log.levels.INFO)
  for _, entry in ipairs(history) do
    local marker = entry.is_current and "* " or "  "
    vim.notify(marker .. entry.index .. ". " .. entry.description, vim.log.levels.INFO)
  end
end

-- Clear command history
function M.clear_history()
  if not M.command_executor then
    vim.notify("Command executor not initialized", vim.log.levels.ERROR)
    return
  end
  
  M.command_executor:clear_history()
  vim.notify("Command history cleared", vim.log.levels.INFO)
end

return M