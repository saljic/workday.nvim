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
  -- Create or get namespace for workday highlights
  local ns = vim.api.nvim_create_namespace("workday_highlights")
  
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  for i, line in ipairs(lines) do
    local line_num = i - 1 -- 0-indexed for extmarks
    local hl_group = nil

    -- Always highlight the header (first line) consistently across all buffers
    if i == 1 then
      hl_group = "WorkdayHeader"
    elseif buffer_type == "todo" then
      if line:match("^%s*-%s*%[x%]") then
        -- Completed todo
        hl_group = "WorkdayCompleted"
      elseif line:match("^%s*-%s*%[%s%]") then
        -- Uncompleted todo
        hl_group = "WorkdayTodo"
      end
    elseif buffer_type == "backlog" then
      if line:match("^%s*-%s") then
        -- Backlog item
        hl_group = "WorkdayBacklog"
      end
    elseif buffer_type == "archive" then
      -- Archive items (treat as completed)
      hl_group = "WorkdayCompleted"
    end

    -- Apply highlight using extmarks if we have a highlight group
    if hl_group then
      vim.api.nvim_buf_set_extmark(buf, ns, line_num, 0, {
        end_line = line_num,
        end_col = #line,
        hl_group = hl_group,
        priority = 100
      })
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

