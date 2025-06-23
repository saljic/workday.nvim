-- Refactored main init module using new abstractions
local config_mod = require("workday.config")
local ui = require("workday.ui_refactored")
local commands_mod = require("workday.commands_refactored")
local highlights = require("workday.highlights_refactored")

local M = {}

M.config = config_mod.config

function M.setup(opts)
  config_mod.setup(opts)
  
  -- Setup autocmd to refresh highlights when colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      if M.view_buffers then
        highlights.refresh_all_highlights(M.view_buffers)
      end
    end,
    desc = "Refresh workday highlights on colorscheme change"
  })
end

function M.open_workday_view()
  -- Check if the workday view is already open
  if M.view_buffers and (vim.api.nvim_buf_is_valid(M.view_buffers.todo_buf) or vim.api.nvim_buf_is_valid(M.view_buffers.archive_buf) or vim.api.nvim_buf_is_valid(M.view_buffers.backlog_buf)) then
    vim.notify("Workday view is already open", vim.log.levels.INFO)
    return
  end
  
  local view_buffers = ui.setup_layout()
  M.view_buffers = view_buffers
  commands_mod.setup_commands(view_buffers)
end

-- Expose for testing
M._ui = ui
M._commands = commands_mod
M._highlights = highlights

-- Legacy compatibility
vim.keymap.set('n', config_mod.config.keymap.start, function() M.open_workday_view() end, { noremap = true, silent = true })

vim.api.nvim_create_user_command("Workday", function()
  M.open_workday_view()
end, { nargs = 0 })

vim.api.nvim_create_user_command("WorkdayRefactored", function()
  M.open_workday_view()
end, { nargs = 0 })

return M