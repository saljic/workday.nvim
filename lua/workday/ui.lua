local config_mod = require("workday.config")
local config = config_mod.config

local M = {}

local function center_text(text, width)
  local padding = math.max(0, math.floor((width - #text) / 2))
  return string.rep(" ", padding) .. text
end

function M.create_scratch_buffer(name, width)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = name or 'workday'
  vim.bo[buf].swapfile = false
  vim.bo[buf].autoindent = false
  vim.bo[buf].smartindent = false
  vim.bo[buf].indentexpr = ''
  vim.bo[buf].indentkeys = ''
  vim.bo[buf].formatoptions = ''
  vim.bo[buf].comments = ''
  vim.api.nvim_buf_set_name(buf, "workday:" .. name)

  width = width or 40
  local header = center_text(string.upper(name), width)
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, { header })

  return buf
end

-- If the file exists, load the content (otherwise reinitialize with header)
function M.load_or_create_buffer(buf, file_path, name, width)
  if vim.loop.fs_stat(file_path) then
    local lines = vim.fn.readfile(file_path)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  else
    width = width or 40
    local header = center_text(string.upper(name), width)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { header })
  end
end

function M.setup_layout()
  vim.cmd('tabnew')
  local main_win = vim.api.nvim_get_current_win()

  vim.cmd('vsplit')
  local right_win = vim.api.nvim_get_current_win()

  vim.cmd('split')
  local bottom_right_win = vim.api.nvim_get_current_win()

  -- Get window widths after splitting
  vim.api.nvim_set_current_win(main_win)
  local todo_width = vim.api.nvim_win_get_width(main_win)

  vim.api.nvim_set_current_win(right_win)
  local backlog_width = vim.api.nvim_win_get_width(right_win)

  vim.api.nvim_set_current_win(bottom_right_win)
  local archive_width = vim.api.nvim_win_get_width(bottom_right_win)

  local todo_buf = M.create_scratch_buffer('todo', todo_width)
  local backlog_buf = M.create_scratch_buffer('backlog', backlog_width)
  local archive_buf = M.create_scratch_buffer('archive', archive_width)

  if config.persistence.enabled then
    M.load_or_create_buffer(todo_buf, config.persistence.todo_file_path, "todo", todo_width)
    M.load_or_create_buffer(backlog_buf, config.persistence.backlog_file_path, "backlog", backlog_width)
    M.load_or_create_buffer(archive_buf, config.persistence.archive_file_path, "archive", archive_width)
  end

  -- Set up the windows with the corresponding buffers
  vim.api.nvim_set_current_win(main_win)
  vim.api.nvim_win_set_buf(main_win, todo_buf)
  vim.wo[main_win].number = false
  vim.wo[main_win].relativenumber = false
  vim.wo[main_win].signcolumn = 'no'

  vim.api.nvim_set_current_win(right_win)
  vim.api.nvim_win_set_buf(right_win, backlog_buf)
  vim.wo[right_win].number = false
  vim.wo[right_win].relativenumber = false
  vim.wo[right_win].signcolumn = 'no'

  vim.api.nvim_set_current_win(bottom_right_win)
  vim.api.nvim_win_set_buf(bottom_right_win, archive_buf)
  vim.wo[bottom_right_win].number = false
  vim.wo[bottom_right_win].relativenumber = false
  vim.wo[bottom_right_win].signcolumn = 'no'

  vim.api.nvim_set_current_win(main_win)

  return {
    todo_win = main_win,
    backlog_win = right_win,
    archive_win = bottom_right_win,
    todo_buf = todo_buf,
    backlog_buf = backlog_buf,
    archive_buf = archive_buf,
  }
end

return M
