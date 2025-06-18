local config = {
  keymap = {
    toggle_todo = "<leader>tt",
    move_to_backlog_top = "<leader>tb",
    archive_completed_tasks = "<leader>ta",
    move_to_todo_bottom = "<leader>td",
  },
  persistence = {
    enabled = true,
    todo_file_path = vim.fn.stdpath('data') .. "/workday_todo.txt",
    backlog_file_path = vim.fn.stdpath('data') .. "/workday_backlog.txt",
    archive_file_path = vim.fn.stdpath('data') .. "/workday_archive.txt",
  }
}

local M = {}

M.config = config

function M.setup(opts)
  opts = opts or {}
  for k, v in pairs(opts) do
    config[k] = v
  end
end

return M
