-- Move Task Command with undo support
local command_base = require("workday.core.command")
local constants = require("workday.core.constants")
local TaskOperations = require("workday.core.task_operations")

local MoveTaskCommand = {}
MoveTaskCommand.__index = MoveTaskCommand
setmetatable(MoveTaskCommand, { __index = command_base.Command })

function MoveTaskCommand:new(buffer_manager, source_type, dest_type, line_numbers, insertion_point)
  local instance = command_base.Command.new(self, {
    buffer_manager = buffer_manager,
    source_buffer_type = source_type,
    dest_buffer_type = dest_type,
    line_numbers = line_numbers or {},
    insertion_point = insertion_point or "bottom",
    moved_tasks = {},
    source_lines_backup = {},
    dest_lines_backup = {}
  })
  return instance
end

function MoveTaskCommand:execute()
  if self.executed then
    return
  end
  
  local buffer_manager = self.data.buffer_manager
  local source_type = self.data.source_buffer_type
  local dest_type = self.data.dest_buffer_type
  local line_numbers = self.data.line_numbers
  
  -- Backup current state
  self.data.source_lines_backup = vim.deepcopy(buffer_manager:get_lines(source_type))
  self.data.dest_lines_backup = vim.deepcopy(buffer_manager:get_lines(dest_type))
  
  -- Extract tasks from source
  local source_lines = buffer_manager:get_lines(source_type)
  local start_line = math.min(unpack(line_numbers))
  local end_line = math.max(unpack(line_numbers))
  
  local tasks = TaskOperations.extract_tasks_from_lines(source_lines, start_line, end_line)
  self.data.moved_tasks = tasks
  
  -- Prepare tasks for destination
  local prepared_tasks = TaskOperations.prepare_tasks_for_destination(tasks, dest_type)
  
  -- Remove tasks from source
  local remaining_source_lines = {}
  for i, line in ipairs(source_lines) do
    local should_keep = true
    for _, line_num in ipairs(line_numbers) do
      if i == line_num then
        should_keep = false
        break
      end
    end
    if should_keep then
      table.insert(remaining_source_lines, line)
    end
  end
  
  -- Add tasks to destination
  local dest_lines = buffer_manager:get_lines(dest_type)
  local insertion_index = #dest_lines + 1
  
  if self.data.insertion_point == "top" then
    insertion_index = 2 -- After header
  end
  
  -- Insert prepared tasks
  for i, task in ipairs(prepared_tasks) do
    table.insert(dest_lines, insertion_index + i - 1, task.line)
  end
  
  -- Update buffers
  buffer_manager:set_lines(source_type, 0, -1, remaining_source_lines)
  buffer_manager:set_lines(dest_type, 0, -1, dest_lines)
  
  -- Clean up and apply highlights
  buffer_manager:cleanup_empty_lines(source_type, false)
  buffer_manager:cleanup_empty_lines(dest_type, false)
  buffer_manager:apply_highlights(source_type)
  buffer_manager:apply_highlights(dest_type)
  
  self.executed = true
end

function MoveTaskCommand:undo()
  if not self.executed then
    return
  end
  
  local buffer_manager = self.data.buffer_manager
  local source_type = self.data.source_buffer_type
  local dest_type = self.data.dest_buffer_type
  
  -- Restore original state
  buffer_manager:set_lines(source_type, 0, -1, self.data.source_lines_backup)
  buffer_manager:set_lines(dest_type, 0, -1, self.data.dest_lines_backup)
  
  -- Apply highlights
  buffer_manager:apply_highlights(source_type)
  buffer_manager:apply_highlights(dest_type)
  
  self.executed = false
end

function MoveTaskCommand:get_description()
  local task_count = #self.data.moved_tasks
  local source_name = self.data.source_buffer_type:gsub("^%l", string.upper)
  local dest_name = self.data.dest_buffer_type:gsub("^%l", string.upper)
  
  if task_count == 1 then
    local task_text = self.data.moved_tasks[1] and self.data.moved_tasks[1].line or "task"
    return string.format("Move '%s' from %s to %s", task_text:sub(1, 30), source_name, dest_name)
  else
    return string.format("Move %d tasks from %s to %s", task_count, source_name, dest_name)
  end
end

return MoveTaskCommand