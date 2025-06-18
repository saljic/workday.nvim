M = {}

function M.strip_prefix(line)
  return line:gsub("^%- %[[ xX]?%] ", "")
end

function M.toggle_completed(line)
  if line:match("^%- %[%s%]") then
    return line:gsub("^%- %[%s%]", "- [x]", 1)
  elseif line:match("^%- %[x%]") or line:match("^%- %[X%]") then
    return line:gsub("^%- %[[xX]%]", "- [ ]", 1)
  end
  return line
end

function M.add_prefix(line)
  return "- [ ] " .. line
end

return M
