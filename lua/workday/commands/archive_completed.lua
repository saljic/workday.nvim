-- Archive Completed Tasks Command with undo support
local command_base = require("workday.core.command")
local constants = require("workday.core.constants")
local utils = require("workday.core.utils")

local ArchiveCompletedCommand = {}
ArchiveCompletedCommand.__index = ArchiveCompletedCommand
setmetatable(ArchiveCompletedCommand, { __index = command_base.Command })

function ArchiveCompletedCommand:new(buffer_manager)
  local instance = command_base.Command.new(self, {
    buffer_manager = buffer_manager,
    archived_tasks = {},
    original_todo_lines = {},
    original_archive_lines = {}
  })
  return instance
end

function ArchiveCompletedCommand:execute()
  if self.executed then
    return
  end
  
  local buffer_manager = self.data.buffer_manager
  
  -- Backup current state
  self.data.original_todo_lines = vim.deepcopy(buffer_manager:get_lines(constants.BUFFER_TYPES.TODO))
  self.data.original_archive_lines = vim.deepcopy(buffer_manager:get_lines(constants.BUFFER_TYPES.ARCHIVE))
  
  local todo_lines = buffer_manager:get_lines(constants.BUFFER_TYPES.TODO)
  local archive_lines = buffer_manager:get_lines(constants.BUFFER_TYPES.ARCHIVE)
  
  -- Find completed tasks
  local completed_tasks = {}
  local remaining_lines = {}
  
  -- Reset archived_tasks to ensure it's a proper array
  self.data.archived_tasks = {}
  
  for i, line in ipairs(todo_lines) do
    if i == 1 then
      -- Keep header
      table.insert(remaining_lines, line)
    elseif utils.is_completed_todo(line) then
      table.insert(completed_tasks, line)
      table.insert(self.data.archived_tasks, line)
    else
      table.insert(remaining_lines, line)
    end
  end
  
  if #completed_tasks == 0 then
    return -- Nothing to archive
  end
  
  -- Add completed tasks to archive (preserve checkbox prefix)
  for _, task in ipairs(completed_tasks) do
    table.insert(archive_lines, task)
  end
  
  -- Update buffers
  buffer_manager:set_lines(constants.BUFFER_TYPES.TODO, 0, -1, remaining_lines)
  buffer_manager:set_lines(constants.BUFFER_TYPES.ARCHIVE, 0, -1, archive_lines)
  
  -- Clean up and apply highlights
  buffer_manager:cleanup_empty_lines(constants.BUFFER_TYPES.TODO, false)
  buffer_manager:cleanup_empty_lines(constants.BUFFER_TYPES.ARCHIVE, false)
  buffer_manager:apply_highlights(constants.BUFFER_TYPES.TODO)
  buffer_manager:apply_highlights(constants.BUFFER_TYPES.ARCHIVE)
  
  self.executed = true
end

function ArchiveCompletedCommand:undo()
  if not self.executed then
    return
  end
  
  local buffer_manager = self.data.buffer_manager
  
  -- Restore original state
  buffer_manager:set_lines(constants.BUFFER_TYPES.TODO, 0, -1, self.data.original_todo_lines)
  buffer_manager:set_lines(constants.BUFFER_TYPES.ARCHIVE, 0, -1, self.data.original_archive_lines)
  
  -- Apply highlights
  buffer_manager:apply_highlights(constants.BUFFER_TYPES.TODO)
  buffer_manager:apply_highlights(constants.BUFFER_TYPES.ARCHIVE)
  
  self.executed = false
end

function ArchiveCompletedCommand:get_description()
  local task_count = #self.data.archived_tasks
  if task_count == 0 then
    return "Archive completed tasks (no tasks found)"
  elseif task_count == 1 then
    return "Archive 1 completed task"
  else
    return string.format("Archive %d completed tasks", task_count)
  end
end

return ArchiveCompletedCommand