local M = {}

M.config = {
  complete_todo_key = "<leader>tt"
}

M.setup = function(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)
end

local function strip_prefix(line)
  return line:gsub("^%- %[[ xX]?%] ", "")
end

local function toggle_completed(line)
  if line:match("^%- %[%s%]") then
    return line:gsub("^%- %[%s%]", "- [x]", 1)
  elseif line:match("^%- %[x%]") or line:match("^%- %[X%]") then
    return line:gsub("^%- %[[xX]%]", "- [ ]", 1)
  end
  return line
end

local function add_prefix(line)
  return "- [ ] " .. line
end

local function create_scratch_buffer(name)
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

  return buf
end

local function setup_layout()
  local todo_buf = create_scratch_buffer('todo')
  local backlog_buf = create_scratch_buffer('backlog')
  local archive_buf = create_scratch_buffer('archive')

  vim.cmd('tabnew')
  local main_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(main_win, todo_buf)
  local todo_win = main_win

  vim.cmd('vsplit')
  local right_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(right_win, backlog_buf)
  local backlog_win = right_win

  vim.cmd('split')
  local bottom_right_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(bottom_right_win, archive_buf)
  local archive_win = bottom_right_win

  vim.api.nvim_set_current_win(todo_win)

  return {
    todo_win = todo_win,
    backlog_win = backlog_win,
    archive_win = archive_win,
    todo_buf = todo_buf,
    backlog_buf = backlog_buf,
    archive_buf = archive_buf
  }
end

local function toggle_todo()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local buf = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]

  if not line then
    return
  end

  local toggled = toggle_completed(line)

  vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { toggled })
end

local function move_to_backlog_top(backlog_buf)
  local cur_buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local line = vim.api.nvim_buf_get_lines(cur_buf, row, row + 1, false)[1]
  if not line or line == "" then return end

  vim.api.nvim_buf_set_lines(cur_buf, row, row + 1, false, {})

  -- Strip the checkbox prefix when moving to backlog
  local stripped_line = strip_prefix(line)
  
  local backlog_lines = vim.api.nvim_buf_get_lines(backlog_buf, 0, -1, false)
  table.insert(backlog_lines, 1, stripped_line)
  vim.api.nvim_buf_set_lines(backlog_buf, 0, -1, false, backlog_lines)
end

local function move_to_todo_bottom(backlog_buf, todo_buf)
  local cur_buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  if cur_buf ~= backlog_buf then
    vim.notify("This command should be used in the backlog buffer", vim.log.levels.ERROR)
    return
  end

  local line = vim.api.nvim_buf_get_lines(cur_buf, row, row + 1, false)[1]
  if not line or line == "" then return end

  vim.api.nvim_buf_set_lines(cur_buf, row, row + 1, false, {})

  -- Always add the checkbox prefix when moving to todo
  local prefixed_line = add_prefix(line)

  local todo_line_count = vim.api.nvim_buf_line_count(todo_buf)

  vim.api.nvim_buf_set_lines(todo_buf, todo_line_count, todo_line_count, false, {prefixed_line})

  vim.api.nvim_echo({{"Moved task to todo list", "Normal"}}, true, {})
end

M.open_workday_view = function()
  local wins = setup_layout()
  local opts = { noremap = true, silent = true, buffer = wins.todo_buf }
  vim.keymap.set('n', M.config.complete_todo_key, toggle_todo, opts)
    vim.keymap.set('n', '<leader>tb', function()
      move_to_backlog_top(wins.backlog_buf)
    end, opts)

  local backlog_opts = { noremap = true, silent = true, buffer = wins.backlog_buf }
  vim.keymap.set('n', '<leader>td', function()
    move_to_todo_bottom(wins.backlog_buf, wins.todo_buf)
  end, backlog_opts)

  vim.api.nvim_create_autocmd("InsertEnter", {
    buffer = wins.todo_buf,
    callback = function()
      local row = vim.api.nvim_win_get_cursor(0)[1] - 1
      local line = vim.api.nvim_buf_get_lines(wins.todo_buf, row, row + 1, false)[1]
      if line then
        local stripped_line = strip_prefix(line)
        if stripped_line ~= line then
          vim.api.nvim_buf_set_lines(wins.todo_buf, row, row + 1, false, { stripped_line })
        end
      end

    end,
  })

  vim.api.nvim_create_autocmd("Insertleave", {
    buffer = wins.todo_buf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(wins.todo_buf, 0, -1, false)
      for i, line in ipairs(lines) do
        if line ~= "" and not line:match("^%- %[[ xX]?%] ") then
          lines[i] = add_prefix(line)
        end
      end
      vim.api.nvim_buf_set_lines(wins.todo_buf, 0, -1, false, lines)
    end,
  })
end

-- M.open_workday_view()
vim.api.nvim_create_user_command('Workday', function()
  M.open_workday_view()
end, { nargs = 0 })


return M
