local config_mod = require("workday.config")
local ui = require("workday.ui")
local commands_mod = require("workday.commands")

local M = {}

M.config = config_mod.config

function M.setup(opts)
  config_mod.setup(opts)
end

function M.open_workday_view()
  local view_buffers = ui.setup_layout()
  M.view_buffers = view_buffers  -- store globally so that other modules can access them
  commands_mod.setup_commands(view_buffers)
end

-- Create the main Workday user command.
vim.api.nvim_create_user_command('Workday', function()
  M.open_workday_view()
end, { nargs = 0 })

return M
