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

local function center_text(text, width)
  local padding = math.max(0, math.floor((width - #text) / 2))
  return string.rep(" ", padding) .. text
end

local function create_scratch_buffer(name, width)
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

  -- Add centered header
  width = width or 40
  local header = center_text(string.upper(name), width)
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, {header})

  return buf
end

local function setup_layout()
  vim.cmd('tabnew')
  local main_win = vim.api.nvim_get_current_win()

  vim.cmd('vsplit')
  local right_win = vim.api.nvim_get_current_win()

  vim.cmd('split')
  local bottom_right_win = vim.api.nvim_get_current_win()

  -- Get actual window widths after splitting
  vim.api.nvim_set_current_win(main_win)
  local todo_width = vim.api.nvim_win_get_width(main_win)
  
  vim.api.nvim_set_current_win(right_win)
  local backlog_width = vim.api.nvim_win_get_width(right_win)
  
  vim.api.nvim_set_current_win(bottom_right_win)
  local archive_width = vim.api.nvim_win_get_width(bottom_right_win)

  local todo_buf = create_scratch_buffer('todo', todo_width)
  local backlog_buf = create_scratch_buffer('backlog', backlog_width)
  local archive_buf = create_scratch_buffer('archive', archive_width)

  vim.api.nvim_set_current_win(main_win)
  vim.api.nvim_win_set_buf(main_win, todo_buf)
  local todo_win = main_win
  vim.wo[todo_win].number = false
  vim.wo[todo_win].relativenumber = false
  vim.wo[todo_win].signcolumn = 'no'

  vim.api.nvim_set_current_win(right_win)
  vim.api.nvim_win_set_buf(right_win, backlog_buf)
  local backlog_win = right_win
  vim.wo[backlog_win].number = false
  vim.wo[backlog_win].relativenumber = false
  vim.wo[backlog_win].signcolumn = 'no'

  vim.api.nvim_set_current_win(bottom_right_win)
  vim.api.nvim_win_set_buf(bottom_right_win, archive_buf)
  local archive_win = bottom_right_win
  vim.wo[archive_win].number = false
  vim.wo[archive_win].relativenumber = false
  vim.wo[archive_win].signcolumn = 'no'

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
  
  -- Skip if in header area
  if row < 1 then
    return
  end
  
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
  
  -- Skip if in header area
  if row < 1 then return end
  
  local line = vim.api.nvim_buf_get_lines(cur_buf, row, row + 1, false)[1]
  if not line or line == "" then return end

  vim.api.nvim_buf_set_lines(cur_buf, row, row + 1, false, {})

  -- Strip the checkbox prefix when moving to backlog
  local stripped_line = strip_prefix(line)
  
  local backlog_lines = vim.api.nvim_buf_get_lines(backlog_buf, 0, -1, false)
  -- Insert after header at the top of content (after line 1, so insert at index 2)
  if #backlog_lines == 1 then
    -- Only header exists, add the line
    table.insert(backlog_lines, stripped_line)
  else
    -- Insert at top of content (position 2 in the array)
    table.insert(backlog_lines, 2, stripped_line)
  end
  vim.api.nvim_buf_set_lines(backlog_buf, 0, -1, false, backlog_lines)
end

local function move_to_todo_bottom(backlog_buf, todo_buf)
  local cur_buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  if cur_buf ~= backlog_buf then
    vim.notify("This command should be used in the backlog buffer", vim.log.levels.ERROR)
    return
  end

  -- Skip if in header area
  if row < 1 then return end

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

  -- Prevent cursor movement to header lines
  local header_prevent_buffers = {wins.todo_buf, wins.backlog_buf, wins.archive_buf}
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
            -- If no content lines exist, create an empty one
            vim.api.nvim_buf_set_lines(buf, -1, -1, false, {""})
            vim.api.nvim_win_set_cursor(0, {2, 0})
          end
        end
      end,
    })
  end

  vim.api.nvim_create_autocmd("InsertEnter", {
    buffer = wins.todo_buf,
    callback = function()
      local row = vim.api.nvim_win_get_cursor(0)[1] - 1
      -- Adjust for header offset
      if row < 1 then return end
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
        -- Skip header line (first line only)
        if i > 1 and line ~= "" and not line:match("^%- %[[ xX]?%] ") then
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
