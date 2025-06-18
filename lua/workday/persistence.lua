local config = require("workday.config").config

local M = {}

local function save_buffer_to_file(buf, file_path)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.fn.writefile(lines, file_path)
end

function M.save_workday(view_buffers)
  if not config.persist then
    vim.notify("Persistence is disabled.", vim.log.levels.INFO)
    return
  end
  if not view_buffers then
    vim.notify("No workday view open.", vim.log.levels.ERROR)
    return
  end
  save_buffer_to_file(view_buffers.todo_buf, config.todo_file)
  save_buffer_to_file(view_buffers.backlog_buf, config.backlog_file)
  save_buffer_to_file(view_buffers.archive_buf, config.archive_file)
  vim.notify("Workday saved.")
end

return M
