local util = require("jira.common.util")

local md = [[## 1. Executive Summary

This document analyzes the implementation.

### Key Objectives
- Enable role CRUD
- Enable role assignment
- Abstract implementation

---

## 2. Analysis

| Component | Purpose |
| --- | --- |
| Client | HTTP |
| API | Facade |

### Code

```elixir
def hello do
  IO.puts "test"
end
```

> This is a quote

- [ ] Task 1
- [x] Task 2
]]

local adf = util.markdown_to_adf(md)
print("Content nodes:", #adf.content)
for i, n in ipairs(adf.content) do
  if n.type == "heading" then
    print(i, "HEADING level " .. n.attrs.level)
  elseif n.type == "bulletList" then
    print(i, "bulletList with " .. #n.content .. " items")
  elseif n.type == "taskList" then
    print(i, "taskList with " .. #n.content .. " items")
  elseif n.type == "table" then
    print(i, "table with " .. #n.content .. " rows")
  elseif n.type == "rule" then
    print(i, "rule")
  elseif n.type == "codeBlock" then
    print(i, "codeBlock lang=" .. (n.attrs.language or "none"))
  elseif n.type == "blockquote" then
    print(i, "blockquote")
  else
    print(i, n.type)
  end
end

print("\nJSON valid:", pcall(vim.json.encode, adf) and "YES" or "NO")
