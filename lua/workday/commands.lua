-- Refactored commands module using new abstractions
local constants = require("workday.core.constants")
local utils = require("workday.core.utils")
local BufferManager = require("workday.core.buffer_manager")
local TaskOperations = require("workday.core.task_operations")
local tasks = require("workday.tasks")
local persistence = require("workday.persistence")
local config = require("workday.config").config

local M = {}

-- Initialize buffer manager for autocmds
local buffer_manager = nil

-- Process lines to add todo prefixes
local function process_lines(buffer_type)
  if not buffer_manager or not buffer_manager:is_valid_state() then
    return
  end
  
  local lines = buffer_manager:get_lines(buffer_type)
  local processed_lines
  
  if buffer_type == constants.BUFFER_TYPES.ARCHIVE then
    processed_lines = TaskOperations.process_archive_lines(lines)
  else
    processed_lines = TaskOperations.process_todo_lines(lines)
  end
  
  buffer_manager:set_lines(buffer_type, 0, -1, processed_lines)
  buffer_manager:cleanup_empty_lines(buffer_type, true)
  buffer_manager:apply_highlights(buffer_type)
end

-- Quit workday view
local function quit(view_buffers)
  if not view_buffers then
    vim.notify("Workday view is not open", vim.log.levels.ERROR)
    return
  end

  persistence.save_workday(view_buffers)

  -- Clean up buffers
  for _, buffer_type in pairs(constants.BUFFER_TYPES) do
    local buf = view_buffers[buffer_type .. "_buf"]
    if utils.is_valid_buffer(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end

function M.setup_commands(view_buffers)
  -- Initialize buffer manager for this session
  buffer_manager = BufferManager:new(view_buffers)
  
  -- Initialize tasks module
  tasks.init(view_buffers)
  
  -- Setup key mappings for the todo buffer
  local todo_opts = { noremap = true, silent = true, buffer = view_buffers.todo_buf }
  vim.keymap.set('n', config.keymap.toggle_todo, tasks.toggle_todo, todo_opts)
  vim.keymap.set('v', config.keymap.toggle_todo, ':<C-u>lua require("workday.tasks").toggle_todo_visual()<CR>', todo_opts)
  vim.keymap.set('n', config.keymap.quit, function() quit(view_buffers) end, todo_opts)
  vim.keymap.set('n', config.keymap.move_to_backlog_top, function() tasks.move_to_backlog_top(view_buffers.backlog_buf) end, todo_opts)
  vim.keymap.set('v', config.keymap.move_to_backlog_top, ':<C-u>lua require("workday.tasks").move_to_backlog_top_visual()<CR>', todo_opts)
  vim.keymap.set('n', config.keymap.archive_completed_tasks, tasks.archive_completed_tasks, todo_opts)
  vim.keymap.set('n', config.keymap.undo, tasks.undo, todo_opts)
  vim.keymap.set('n', config.keymap.redo, tasks.redo, todo_opts)
  vim.keymap.set('n', config.keymap.show_history, tasks.show_history, todo_opts)

  -- Setup key mappings for the backlog buffer
  local backlog_opts = { noremap = true, silent = true, buffer = view_buffers.backlog_buf }
  vim.keymap.set('n', config.keymap.move_to_todo_bottom, function() tasks.move_to_todo_bottom(view_buffers.backlog_buf, view_buffers.todo_buf) end, backlog_opts)
  vim.keymap.set('v', config.keymap.move_to_todo_bottom, ':<C-u>lua require("workday.tasks").move_to_todo_bottom_visual(' .. view_buffers.backlog_buf .. ', ' .. view_buffers.todo_buf .. ')<CR>', backlog_opts)
  vim.keymap.set('n', config.keymap.quit, function() quit(view_buffers) end, backlog_opts)
  vim.keymap.set('n', config.keymap.undo, tasks.undo, backlog_opts)
  vim.keymap.set('n', config.keymap.redo, tasks.redo, backlog_opts)
  vim.keymap.set('n', config.keymap.show_history, tasks.show_history, backlog_opts)

  -- Setup key mappings for the archive buffer
  local archive_opts = { noremap = true, silent = true, buffer = view_buffers.archive_buf }
  vim.keymap.set('n', config.keymap.move_to_todo_bottom, function() tasks.move_to_todo_bottom(view_buffers.archive_buf, view_buffers.todo_buf) end, archive_opts)
  vim.keymap.set('v', config.keymap.move_to_todo_bottom, ':<C-u>lua require("workday.tasks").move_to_todo_bottom_visual(' .. view_buffers.archive_buf .. ', ' .. view_buffers.todo_buf .. ')<CR>', archive_opts)
  vim.keymap.set('n', config.keymap.quit, function() quit(view_buffers) end, archive_opts)
  vim.keymap.set('n', config.keymap.undo, tasks.undo, archive_opts)
  vim.keymap.set('n', config.keymap.redo, tasks.redo, archive_opts)
  vim.keymap.set('n', config.keymap.show_history, tasks.show_history, archive_opts)

  -- Setup autocmds for cursor movement prevention
  local header_prevent_buffers = {
    view_buffers.todo_buf,
    view_buffers.backlog_buf,
    view_buffers.archive_buf
  }
  
  for _, buf in ipairs(header_prevent_buffers) do
    vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
      buffer = buf,
      callback = function()
        local row = vim.api.nvim_win_get_cursor(0)[1]
        if row <= 1 then
          local line_count = vim.api.nvim_buf_line_count(buf)
          if line_count >= 2 then
            vim.api.nvim_win_set_cursor(0, {2, 0})
          else
            vim.api.nvim_buf_set_lines(buf, -1, -1, false, {""})
            vim.api.nvim_win_set_cursor(0, {2, 0})
          end
        end
      end,
    })
  end


  -- Setup InsertLeave autocmds
  vim.api.nvim_create_autocmd("InsertLeave", {
    buffer = view_buffers.todo_buf,
    callback = function()
      process_lines(constants.BUFFER_TYPES.TODO)
      persistence.save_workday(view_buffers)
    end,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    buffer = view_buffers.archive_buf,
    callback = function()
      process_lines(constants.BUFFER_TYPES.ARCHIVE)
      persistence.save_workday(view_buffers)
    end,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    buffer = view_buffers.backlog_buf,
    callback = function()
      buffer_manager:cleanup_empty_lines(constants.BUFFER_TYPES.BACKLOG, true)
      buffer_manager:apply_highlights(constants.BUFFER_TYPES.BACKLOG)
      persistence.save_workday(view_buffers)
    end,
  })

  -- Setup TextChanged autocmds
  vim.api.nvim_create_autocmd("TextChanged", {
    buffer = view_buffers.todo_buf,
    callback = function()
      process_lines(constants.BUFFER_TYPES.TODO)
      persistence.save_workday(view_buffers)
    end,
  })
  
  vim.api.nvim_create_autocmd("TextChanged", {
    buffer = view_buffers.archive_buf,
    callback = function()
      process_lines(constants.BUFFER_TYPES.ARCHIVE)
      persistence.save_workday(view_buffers)
    end,
  })

  vim.api.nvim_create_autocmd("TextChanged", {
    buffer = view_buffers.backlog_buf,
    callback = function()
      persistence.save_workday(view_buffers)
    end,
  })
end

return M