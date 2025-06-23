local config = {
  keymap = {
    toggle_todo = "<leader>tt", -- Toggle todo
    move_to_backlog_top = "<leader>tb", -- Move todo to backlog top
    archive_completed_tasks = "<leader>ta", -- Archive completed tasks
    move_to_todo_bottom = "<leader>td", -- Move backlog/archive to todo bottom
    quit = "q", -- Quit workday view
    start = "<leader>ow", -- Open workday view
    undo = "u", -- Undo last action
    redo = "U", -- Redo last undone action
    show_history = "<leader>th", -- Show command history
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
