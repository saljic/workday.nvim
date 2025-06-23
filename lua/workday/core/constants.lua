-- Core constants for workday.nvim
local M = {}

-- Buffer types
M.BUFFER_TYPES = {
  TODO = "todo",
  BACKLOG = "backlog",
  ARCHIVE = "archive"
}

-- Movement positions
M.POSITIONS = {
  TOP = "top",
  BOTTOM = "bottom"
}

-- Line patterns
M.PATTERNS = {
  TODO_UNCOMPLETED = "^%s*-%s*%[%s%]",
  TODO_COMPLETED = "^%s*-%s*%[x%]",
  TODO_COMPLETED_UPPER = "^%s*-%s*%[X%]",
  TODO_PREFIX = "^%- %[[ xX]?%] ",
  BACKLOG_ITEM = "^%s*-%s",
  NON_EMPTY = "%S"
}

-- Highlight groups
M.HIGHLIGHT_GROUPS = {
  HEADER = "WorkdayHeader",
  TODO = "WorkdayTodo", 
  COMPLETED = "WorkdayCompleted",
  BACKLOG = "WorkdayBacklog"
}

-- Default highlight mappings
M.DEFAULT_HIGHLIGHTS = {
  [M.HIGHLIGHT_GROUPS.HEADER] = { link = "Title" },
  [M.HIGHLIGHT_GROUPS.TODO] = { link = "Normal" },
  [M.HIGHLIGHT_GROUPS.COMPLETED] = { link = "Comment" },
  [M.HIGHLIGHT_GROUPS.BACKLOG] = { link = "String" }
}

-- Namespace for highlights
M.HIGHLIGHT_NAMESPACE = "workday_highlights"

return M