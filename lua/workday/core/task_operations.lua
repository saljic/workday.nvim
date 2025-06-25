-- Pure business logic for task operations
local constants = require("workday.core.constants")
local utils = require("workday.core.utils")

local M = {}

-- Toggle completion state of a single task line
function M.toggle_task_completion(line)
  if not line or line == "" then
    return line
  end
  
  return utils.toggle_todo_completion(line)
end

-- Process lines to ensure they have todo prefixes
function M.process_todo_lines(lines)
  local processed_lines = {}
  
  for i, line in ipairs(lines) do
    if i == 1 then
      -- Keep header unchanged
      table.insert(processed_lines, line)
    elseif line ~= "" and not utils.is_todo_line(line) then
      -- Add todo prefix to non-empty lines that don't have it
      table.insert(processed_lines, utils.add_todo_prefix(line))
    else
      -- Keep existing lines unchanged
      table.insert(processed_lines, line)
    end
  end
  
  return processed_lines
end

-- Extract tasks from lines for movement
function M.extract_tasks_from_lines(lines, start_row, end_row)
  local tasks = {}
  
  -- Ensure valid range
  start_row = math.max(2, start_row)  -- Skip header
  end_row = math.min(#lines, end_row)
  
  for i = start_row, end_row do
    local line = lines[i]
    if line and line ~= "" then
      table.insert(tasks, {
        line = line,
        original_index = i
      })
    end
  end
  
  return tasks
end

-- Prepare tasks for destination buffer
function M.prepare_tasks_for_destination(tasks, destination_type)
  local prepared_tasks = {}
  
  for _, task in ipairs(tasks) do
    local prepared_line = task.line
    
    if destination_type == constants.BUFFER_TYPES.TODO then
      -- Add todo prefix if moving to todo buffer
      if not utils.is_todo_line(prepared_line) then
        prepared_line = utils.add_todo_prefix(prepared_line)
      end
    elseif destination_type == constants.BUFFER_TYPES.BACKLOG then
      -- Strip todo prefix if moving to backlog
      if utils.is_todo_line(prepared_line) then
        prepared_line = utils.strip_todo_prefix(prepared_line)
      end
    elseif destination_type == constants.BUFFER_TYPES.ARCHIVE then
      -- Keep todo prefix when moving to archive (preserve completion state)
      if not utils.is_todo_line(prepared_line) then
        prepared_line = utils.add_todo_prefix(prepared_line)
      end
    end
    
    table.insert(prepared_tasks, {
      line = prepared_line,
      original_task = task
    })
  end
  
  return prepared_tasks
end

-- Insert tasks into destination lines at specified position
function M.insert_tasks_at_position(destination_lines, tasks, position)
  local result_lines = {}
  
  -- Always keep header
  if #destination_lines > 0 then
    table.insert(result_lines, destination_lines[1])
  end
  
  if position == constants.POSITIONS.TOP then
    -- Insert tasks at top (after header)
    for _, task in ipairs(tasks) do
      table.insert(result_lines, task.line)
    end
    
    -- Add existing content after tasks
    for i = 2, #destination_lines do
      if utils.line_has_content(destination_lines[i]) then
        table.insert(result_lines, destination_lines[i])
      end
    end
  elseif position == constants.POSITIONS.BOTTOM then
    -- Add existing content first
    for i = 2, #destination_lines do
      if utils.line_has_content(destination_lines[i]) then
        table.insert(result_lines, destination_lines[i])
      end
    end
    
    -- Insert tasks at bottom
    for _, task in ipairs(tasks) do
      table.insert(result_lines, task.line)
    end
  end
  
  return result_lines
end

-- Remove tasks from source lines
function M.remove_tasks_from_lines(source_lines, tasks)
  local result_lines = {}
  local indices_to_remove = {}
  
  -- Collect indices to remove
  for _, task in ipairs(tasks) do
    indices_to_remove[task.original_index] = true
  end
  
  -- Keep lines that are not being removed
  for i, line in ipairs(source_lines) do
    if not indices_to_remove[i] then
      table.insert(result_lines, line)
    end
  end
  
  return result_lines
end

-- Find completed tasks in lines
function M.find_completed_tasks(lines)
  local completed_tasks = {}
  
  for i = 2, #lines do  -- Skip header
    local line = lines[i]
    if utils.is_completed_todo(line) then
      table.insert(completed_tasks, {
        line = line,
        original_index = i
      })
    end
  end
  
  return completed_tasks
end

-- Create a move operation result
function M.create_move_result(source_lines, destination_lines, tasks, destination_type, position)
  -- Prepare tasks for destination
  local prepared_tasks = M.prepare_tasks_for_destination(tasks, destination_type)
  
  -- Create new destination lines
  local new_destination_lines = M.insert_tasks_at_position(destination_lines, prepared_tasks, position)
  
  -- Create new source lines (remove moved tasks)
  local new_source_lines = M.remove_tasks_from_lines(source_lines, tasks)
  
  return {
    source_lines = new_source_lines,
    destination_lines = new_destination_lines,
    moved_tasks_count = #tasks
  }
end

-- Validate move operation
function M.validate_move_operation(source_type, destination_type, position)
  if not utils.is_valid_buffer_type(source_type) then
    return false, "Invalid source buffer type: " .. tostring(source_type)
  end
  
  if not utils.is_valid_buffer_type(destination_type) then
    return false, "Invalid destination buffer type: " .. tostring(destination_type)
  end
  
  if source_type == destination_type then
    return false, "Source and destination cannot be the same"
  end
  
  if position ~= constants.POSITIONS.TOP and position ~= constants.POSITIONS.BOTTOM then
    return false, "Invalid position: " .. tostring(position)
  end
  
  return true, "Valid operation"
end

-- High-level move operation
function M.move_tasks(source_type, destination_type, selection_range, position)
  -- Validate operation
  local valid, error_msg = M.validate_move_operation(source_type, destination_type, position)
  if not valid then
    return nil, error_msg
  end
  
  return {
    source_type = source_type,
    destination_type = destination_type,
    selection_range = selection_range,
    position = position,
    operation_type = "move"
  }
end

-- High-level toggle operation  
function M.toggle_tasks(buffer_type, selection_range)
  if not utils.is_valid_buffer_type(buffer_type) then
    return nil, "Invalid buffer type: " .. tostring(buffer_type)
  end
  
  return {
    buffer_type = buffer_type,
    selection_range = selection_range,
    operation_type = "toggle"
  }
end

-- High-level archive operation
function M.archive_completed_tasks(source_type, destination_type)
  -- Validate operation
  local valid, error_msg = M.validate_move_operation(source_type, destination_type, constants.POSITIONS.BOTTOM)
  if not valid then
    return nil, error_msg
  end
  
  return {
    source_type = source_type,
    destination_type = destination_type,
    position = constants.POSITIONS.BOTTOM,
    operation_type = "archive",
    filter_completed = true
  }
end

return M