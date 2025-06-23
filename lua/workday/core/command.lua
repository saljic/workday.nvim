-- Command Pattern implementation for workday.nvim
-- Provides undo/redo functionality and better separation of concerns

local M = {}

-- Base Command interface
local Command = {}
Command.__index = Command

function Command:new(data)
  local instance = setmetatable({}, self)
  instance.data = data or {}
  instance.executed = false
  return instance
end

function Command:execute()
  error("Command:execute() must be implemented by subclass")
end

function Command:undo()
  error("Command:undo() must be implemented by subclass")
end

function Command:can_undo()
  return self.executed
end

function Command:get_description()
  return "Generic Command"
end

M.Command = Command

-- Command History for undo/redo functionality
local CommandHistory = {}
CommandHistory.__index = CommandHistory

function CommandHistory:new(max_history)
  local instance = setmetatable({}, self)
  instance.history = {}
  instance.current_index = 0
  instance.max_history = max_history or 50
  return instance
end

function CommandHistory:execute(command)
  -- Execute the command
  local success, error_msg = pcall(function()
    command:execute()
  end)
  
  if not success then
    return false, error_msg
  end
  
  -- Remove any commands after current index (when we're in middle of history)
  for i = self.current_index + 1, #self.history do
    self.history[i] = nil
  end
  
  -- Add command to history
  self.current_index = self.current_index + 1
  self.history[self.current_index] = command
  
  -- Trim history if needed
  if #self.history > self.max_history then
    table.remove(self.history, 1)
    self.current_index = self.current_index - 1
  end
  
  return true
end

function CommandHistory:undo()
  if self.current_index <= 0 then
    return false, "Nothing to undo"
  end
  
  local command = self.history[self.current_index]
  if not command:can_undo() then
    return false, "Command cannot be undone"
  end
  
  local success, error_msg = pcall(function()
    command:undo()
  end)
  
  if success then
    self.current_index = self.current_index - 1
    return true
  else
    return false, error_msg
  end
end

function CommandHistory:redo()
  if self.current_index >= #self.history then
    return false, "Nothing to redo"
  end
  
  local command = self.history[self.current_index + 1]
  local success, error_msg = pcall(function()
    command:execute()
  end)
  
  if success then
    self.current_index = self.current_index + 1
    return true
  else
    return false, error_msg
  end
end

function CommandHistory:can_undo()
  return self.current_index > 0
end

function CommandHistory:can_redo()
  return self.current_index < #self.history
end

function CommandHistory:get_history()
  local history_info = {}
  for i, command in ipairs(self.history) do
    table.insert(history_info, {
      index = i,
      description = command:get_description(),
      is_current = i == self.current_index
    })
  end
  return history_info
end

function CommandHistory:clear()
  self.history = {}
  self.current_index = 0
end

M.CommandHistory = CommandHistory

-- Command Executor - Central point for all command execution
local CommandExecutor = {}
CommandExecutor.__index = CommandExecutor

function CommandExecutor:new(buffer_manager)
  local instance = setmetatable({}, self)
  instance.buffer_manager = buffer_manager
  instance.history = CommandHistory:new()
  return instance
end

function CommandExecutor:execute(command)
  return self.history:execute(command)
end

function CommandExecutor:undo()
  return self.history:undo()
end

function CommandExecutor:redo()
  return self.history:redo()
end

function CommandExecutor:can_undo()
  return self.history:can_undo()
end

function CommandExecutor:can_redo()
  return self.history:can_redo()
end

function CommandExecutor:get_history()
  return self.history:get_history()
end

function CommandExecutor:clear_history()
  self.history:clear()
end

M.CommandExecutor = CommandExecutor

return M