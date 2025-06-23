-- Toggle Todo Command with undo support
local command_base = require("workday.core.command")
local constants = require("workday.core.constants")
local utils = require("workday.core.utils")

local ToggleTodoCommand = {}
ToggleTodoCommand.__index = ToggleTodoCommand
setmetatable(ToggleTodoCommand, { __index = command_base.Command })

function ToggleTodoCommand:new(buffer_manager, buffer_type, line_number, line_content)  
  local instance = command_base.Command.new(self, {
    buffer_manager = buffer_manager,
    buffer_type = buffer_type,
    line_number = line_number,
    original_line = line_content,
    new_line = nil
  })
  return instance
end

function ToggleTodoCommand:execute()
  if self.executed then
    return
  end
  
  local buffer_manager = self.data.buffer_manager
  local buffer_type = self.data.buffer_type
  local line_number = self.data.line_number
  local original_line = self.data.original_line
  
  -- Toggle the todo completion
  local new_line = utils.toggle_todo_completion(original_line)
  self.data.new_line = new_line
  
  -- Update the buffer
  local lines = buffer_manager:get_lines(buffer_type)
  if line_number <= #lines then
    lines[line_number] = new_line
    buffer_manager:set_lines(buffer_type, 0, -1, lines)
    buffer_manager:apply_highlights(buffer_type)
  end
  
  self.executed = true
end

function ToggleTodoCommand:undo()
  if not self.executed then
    return
  end
  
  local buffer_manager = self.data.buffer_manager
  local buffer_type = self.data.buffer_type
  local line_number = self.data.line_number
  local original_line = self.data.original_line
  
  -- Restore original line
  local lines = buffer_manager:get_lines(buffer_type)
  if line_number <= #lines then
    lines[line_number] = original_line
    buffer_manager:set_lines(buffer_type, 0, -1, lines)
    buffer_manager:apply_highlights(buffer_type)
  end
  
  self.executed = false
end

function ToggleTodoCommand:get_description()
  local original = self.data.original_line or ""
  local new_line = self.data.new_line or ""
  
  if utils.is_completed_todo(new_line) then
    return "Complete todo: " .. utils.strip_todo_prefix(original)
  else
    return "Uncomplete todo: " .. utils.strip_todo_prefix(original)
  end
end

return ToggleTodoCommand