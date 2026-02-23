-- Test JSON encoding with vim.NIL
local test_cases = {
  {
    name = "vim.NIL",
    fields = { description = vim.NIL }
  },
  {
    name = "empty ADF",
    fields = { description = { type = "doc", version = 1, content = {} } }
  },
  {
    name = "nil value",
    fields = { description = nil }
  },
}

for _, test in ipairs(test_cases) do
  print("\n=== " .. test.name .. " ===")
  local data = { fields = test.fields }
  local ok, json = pcall(vim.json.encode, data)
  print("OK:", ok)
  if ok then
    print("JSON:", json)
  else
    print("Error:", json)
  end
end
