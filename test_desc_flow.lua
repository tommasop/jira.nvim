-- Simulate EXACTLY what happens when user deletes all description

-- Case 1: Buffer has empty line after ---
local lines_with_empty = {
  "# Test Summary",
  "",
  "**Priority**: Medium",
  "",
  "---",
  "",  -- Empty line after separator
}

-- Case 2: Buffer ends right after ---
local lines_no_content = {
  "# Test Summary",
  "",
  "**Priority**: Medium",
  "",
  "---",
}

local function test_buffer(lines, name)
  print("\n=== " .. name .. " ===")
  
  local in_description = false
  local desc_lines = {}
  
  for i, line in ipairs(lines) do
    if i == 1 and line:match("^# ") then
      -- summary
    elseif not in_description and line:match("^%s*---%s*$") then
      in_description = true
      print("Found separator at line " .. i)
    elseif not in_description then
      -- metadata
    elseif in_description then
      table.insert(desc_lines, line)
      print("Added to desc_lines: line " .. i .. " = [" .. line .. "]")
    end
  end
  
  print("in_description:", in_description)
  print("desc_lines count:", #desc_lines)
  
  if in_description then
    local description_text = table.concat(desc_lines, "\n")
    description_text = description_text:gsub("^%s+", ""):gsub("%s+$", "")
    print("description_text: [" .. description_text .. "]")
    print("is empty:", description_text == "")
    
    if description_text == "" then
      print("Would set fields.description = vim.NIL")
    end
  else
    print("in_description is FALSE - description field would NOT be updated!")
  end
end

test_buffer(lines_with_empty, "With empty line after separator")
test_buffer(lines_no_content, "No content after separator")
