package.loaded['jira.common.util'] = nil
local util = require("jira.common.util")

local md = [[text

---

]]

print("Testing round-trip:")
local adf = util.markdown_to_adf(md)
print("ADF content count:", #adf.content)
for i, n in ipairs(adf.content) do
  print(i, n.type, n.content and #n.content or "")
  if n.type == "paragraph" and n.content then
    print("  text:", n.content[1].text)
  end
end
local back_md = util.adf_to_markdown(adf)
print("Original MD length:", #md)
print("Back MD length:", #back_md)
print("Contains ┌ in back:", back_md:find("┌") and "yes" or "no")
print("Contains ``` in back:", back_md:find("```") and "yes" or "no")

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
    print(i, "codeBlock lang=" .. (n.attrs and n.attrs.language or "none"))
  elseif n.type == "blockquote" then
    print(i, "blockquote")
  elseif n.type == "paragraph" then
    print(i, "paragraph:", n.content[1].text:sub(1,20))
  else
    print(i, n.type)
  end
end

print("\nJSON valid:", pcall(vim.json.encode, adf) and "YES" or "NO")
