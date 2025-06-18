local config = require("workday.config").config
local ui = require("workday.ui")
local tasks = require("workday.tasks")
local persistence = require("workday.persistence")

local M = {}

function M.setup_commands(view_buffers)
  -- Setup key mappings for the todo buffer.
  local todo_opts = { noremap = true, silent = true, buffer = view_buffers.todo_buf }
  vim.keymap.set('n', config.keymap.toggle_todo, tasks.toggle_todo, todo_opts)
  vim.keymap.set('n', config.keymap.move_to_backlog_top, function() tasks.move_to_backlog_top(view_buffers.backlog_buf) end, todo_opts)
  vim.keymap.set('n', config.keymap.archive_completed_tasks, tasks.archive_completed_tasks, todo_opts)

  local backlog_opts = { noremap = true, silent = true, buffer = view_buffers.backlog_buf }
  vim.keymap.set('n', config.keymap.move_to_todo_bottom, function() tasks.move_to_todo_bottom(view_buffers.backlog_buf, view_buffers.todo_buf) end, backlog_opts)

  local archive_opts = { noremap = true, silent = true, buffer = view_buffers.archive_buf }
  vim.keymap.set('n', config.keymap.move_to_todo_bottom, function() tasks.move_to_todo_bottom(view_buffers.archive_buf, view_buffers.todo_buf) end, archive_opts)

  -- Prevent moving the cursor into header lines.
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

  -- Auto-remove checkbox prefix when entering insert mode.
  vim.api.nvim_create_autocmd("InsertEnter", {
    buffer = view_buffers.todo_buf,
    callback = function()
      local row = vim.api.nvim_win_get_cursor(0)[1] - 1
      if row < 1 then return end
      local line = vim.api.nvim_buf_get_lines(view_buffers.todo_buf, row, row+1, false)[1]
      if line then
        local stripped_line = line:gsub("^%- %[[ xX]?%] ", "")
        if stripped_line ~= line then
          vim.api.nvim_buf_set_lines(view_buffers.todo_buf, row, row+1, false, {stripped_line})
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    buffer = view_buffers.todo_buf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(view_buffers.todo_buf, 0, -1, false)
      for i, line in ipairs(lines) do
        if i > 1 and line ~= "" and not line:match("^%- %[[ xX]?%] ") then
          lines[i] = "- [ ] " .. line
        end
      end
      vim.api.nvim_buf_set_lines(view_buffers.todo_buf, 0, -1, false, lines)
    end,
  })

  -- Create user commands for added convenience.
  vim.api.nvim_create_user_command('WorkdayArchive', tasks.archive_completed_tasks, { nargs = 0 })
  vim.api.nvim_create_user_command('WorkdaySave', function() persistence.save_workday(view_buffers) end, { nargs = 0 })
end

return M
