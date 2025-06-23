-- Refactored highlights module using new abstractions
local constants = require("workday.core.constants")
local BufferManager = require("workday.core.buffer_manager")

local M = {}

function M.setup_highlights()
  BufferManager.setup_highlight_groups()
end

function M.apply_buffer_highlights(buf, buffer_type)
  -- This is now handled by BufferManager.apply_highlights()
  -- Kept for backward compatibility during transition
  local view_buffers = require("workday").view_buffers
  if view_buffers then
    local buffer_manager = BufferManager:new(view_buffers)
    buffer_manager:apply_highlights(buffer_type)
  end
end

function M.refresh_all_highlights(view_buffers)
  if not view_buffers then
    return
  end
  
  local buffer_manager = BufferManager:new(view_buffers)
  buffer_manager:refresh_all_highlights()
end

return M