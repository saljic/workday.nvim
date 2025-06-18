local config = require("workday.config").config

local M = {}

local function save_buffer_to_file(buf, file_path)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.fn.writefile(lines, file_path)
end

function M.save_workday(view_buffers)
  if not config.persistence.enabled then
    vim.notify("Persistence is disabled.", vim.log.levels.INFO)
    return
  end
  if not view_buffers then
    vim.notify("No workday view open.", vim.log.levels.ERROR)
    return
  end
  save_buffer_to_file(view_buffers.todo_buf, config.persistence.todo_file_path)
  save_buffer_to_file(view_buffers.backlog_buf, config.persistence.backlog_file_path)
  save_buffer_to_file(view_buffers.archive_buf, config.persistence.archive_file_path)
end

return M
