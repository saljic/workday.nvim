local M = {}

function M.setup_highlights()
  -- Define highlight groups that link to existing colorscheme highlights
  local highlights = {
    WorkdayHeader = { link = "Title" },
    WorkdayTodo = { link = "Normal" },
    WorkdayCompleted = { link = "Comment" },
    WorkdayBacklog = { link = "String" },
  }

  -- Apply the highlight groups
  for group, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

function M.apply_buffer_highlights(buf, buffer_type)
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  for i, line in ipairs(lines) do
    local line_num = i - 1 -- 0-indexed for nvim_buf_add_highlight

    -- Always highlight the header (first line) consistently across all buffers
    if i == 1 then
      vim.api.nvim_buf_add_highlight(buf, -1, "WorkdayHeader", line_num, 0, -1)
    elseif buffer_type == "todo" then
      if line:match("^%s*-%s*%[x%]") then
        -- Completed todo
        vim.api.nvim_buf_add_highlight(buf, -1, "WorkdayCompleted", line_num, 0, -1)
      elseif line:match("^%s*-%s*%[%s%]") then
        -- Uncompleted todo
        vim.api.nvim_buf_add_highlight(buf, -1, "WorkdayTodo", line_num, 0, -1)
      end
    elseif buffer_type == "backlog" then
      if line:match("^%s*-%s") then
        -- Backlog item
        vim.api.nvim_buf_add_highlight(buf, -1, "WorkdayBacklog", line_num, 0, -1)
      end
    elseif buffer_type == "archive" then
      -- Archive items (treat as completed)
      vim.api.nvim_buf_add_highlight(buf, -1, "WorkdayCompleted", line_num, 0, -1)
    end
  end
end

function M.refresh_all_highlights(view_buffers)
  if not view_buffers then
    return
  end

  -- Re-setup highlight groups in case colorscheme changed
  M.setup_highlights()

  -- Re-apply buffer highlights
  if vim.api.nvim_buf_is_valid(view_buffers.todo_buf) then
    M.apply_buffer_highlights(view_buffers.todo_buf, "todo")
  end
  if vim.api.nvim_buf_is_valid(view_buffers.backlog_buf) then
    M.apply_buffer_highlights(view_buffers.backlog_buf, "backlog")
  end
  if vim.api.nvim_buf_is_valid(view_buffers.archive_buf) then
    M.apply_buffer_highlights(view_buffers.archive_buf, "archive")
  end
end

return M

