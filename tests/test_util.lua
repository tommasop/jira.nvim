local Helpers = dofile("tests/helpers.lua")

local child = Helpers.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    -- This will be executed before every (even nested) case
    pre_case = function()
      -- Restart child process with custom 'init.lua' script
      child.restart({ "-u", "scripts/minimal_init.lua" })
    end,
    -- This will be executed one after all tests from this set are finished
    post_once = child.stop,
  },
})

T["util"] = MiniTest.new_set()

T["util"]["format_time"] = MiniTest.new_set()

T["util"]["format_time"]["should return 0 for nil or <= 0"] = function()
  child.lua([[M = require("jira.common.util")]])
  MiniTest.expect.equality(child.lua_get([[M.format_time(nil)]]), "0")
  MiniTest.expect.equality(child.lua_get([[M.format_time(0)]]), "0")
  MiniTest.expect.equality(child.lua_get([[M.format_time(-10)]]), "0")
end

T["util"]["format_time"]["should format seconds to hours"] = function()
  child.lua([[M = require("jira.common.util")]])
  MiniTest.expect.equality(child.lua_get([[M.format_time(3600)]]), "1")
  MiniTest.expect.equality(child.lua_get([[M.format_time(7200)]]), "2")
end

T["util"]["format_time"]["should show one decimal place for non-integers"] = function()
  child.lua([[M = require("jira.common.util")]])
  MiniTest.expect.equality(child.lua_get([[M.format_time(1800)]]), "0.5")
  MiniTest.expect.equality(child.lua_get([[M.format_time(5400)]]), "1.5")
end

T["util"]["strim"] = function()
  child.lua([[M = require("jira.common.util")]])
  MiniTest.expect.equality(child.lua_get([[M.strim("  hello  ")]]), "hello")
  MiniTest.expect.equality(child.lua_get([[M.strim("\n hello world \t")]]), "hello world")
end

T["util"]["markdown_to_adf"] = MiniTest.new_set()

T["util"]["markdown_to_adf"]["should convert simple text to ADF"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[adf = M.markdown_to_adf("hello world")]])
  MiniTest.expect.equality(child.lua_get([[adf.type]]), "doc")
  MiniTest.expect.equality(child.lua_get([[#adf.content]]), 1)
  MiniTest.expect.equality(child.lua_get([[adf.content[1].type]]), "paragraph")
  MiniTest.expect.equality(child.lua_get([[adf.content[1].content[1].text]]), "hello world")
end

T["util"]["markdown_to_adf"]["should handle bold text"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[adf = M.markdown_to_adf("hello **world**")]])
  child.lua([[content = adf.content[1].content]])
  MiniTest.expect.equality(child.lua_get([[content[1].text]]), "hello ")
  MiniTest.expect.equality(child.lua_get([[content[2].text]]), "world")
  MiniTest.expect.equality(child.lua_get([[content[2].marks[1].type]]), "strong")
end

T["util"]["markdown_to_adf"]["should handle links"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[adf = M.markdown_to_adf("[Google](https://google.com)")]])
  child.lua([[content = adf.content[1].content]])
  MiniTest.expect.equality(child.lua_get([[content[1].text]]), "Google")
  MiniTest.expect.equality(child.lua_get([[content[1].marks[1].type]]), "link")
  MiniTest.expect.equality(child.lua_get([[content[1].marks[1].attrs.href]]), "https://google.com")
end

T["util"]["markdown_to_adf"]["should handle multiple paragraphs"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[adf = M.markdown_to_adf("p1\n\np2")]])
  MiniTest.expect.equality(child.lua_get([[#adf.content]]), 2)
  MiniTest.expect.equality(child.lua_get([[adf.content[1].content[1].text]]), "p1")
  MiniTest.expect.equality(child.lua_get([[adf.content[2].content[1].text]]), "p2")
end

T["util"]["markdown_to_adf"]["should handle italic text"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[adf = M.markdown_to_adf("hello *world*")]])
  child.lua([[content = adf.content[1].content]])
  MiniTest.expect.equality(child.lua_get([[content[1].text]]), "hello ")
  MiniTest.expect.equality(child.lua_get([[content[2].text]]), "world")
  MiniTest.expect.equality(child.lua_get([[content[2].marks[1].type]]), "em")
end

T["util"]["markdown_to_adf"]["should handle inline code"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[adf = M.markdown_to_adf("use `code` here")]])
  child.lua([[content = adf.content[1].content]])
  MiniTest.expect.equality(child.lua_get([[content[1].text]]), "use ")
  MiniTest.expect.equality(child.lua_get([[content[2].text]]), "code")
  MiniTest.expect.equality(child.lua_get([[content[2].marks[1].type]]), "code")
end

T["util"]["markdown_to_adf"]["should handle strikethrough"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[adf = M.markdown_to_adf("~~deleted~~ text")]])
  child.lua([[content = adf.content[1].content]])
  MiniTest.expect.equality(child.lua_get([[content[1].text]]), "deleted")
  MiniTest.expect.equality(child.lua_get([[content[1].marks[1].type]]), "strike")
  MiniTest.expect.equality(child.lua_get([[content[2].text]]), " text")
end



T["util"]["markdown_to_adf"]["should handle blockquote"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[adf = M.markdown_to_adf("> quoted text")]])
  MiniTest.expect.equality(child.lua_get([[adf.content[1].type]]), "blockquote")
end

T["util"]["markdown_to_adf"]["should handle task list"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[adf = M.markdown_to_adf("- [ ] pending\n- [x] done")]])
  MiniTest.expect.equality(child.lua_get([[adf.content[1].type]]), "taskList")
  MiniTest.expect.equality(child.lua_get([[adf.content[1].content[1].attrs.status]]), "pending")
  MiniTest.expect.equality(child.lua_get([[adf.content[1].content[2].attrs.status]]), "done")
end

T["util"]["markdown_to_adf"]["should handle table"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[adf = M.markdown_to_adf("| h1 | h2 |\n|---|---|\n| c1 | c2 |")]])
  MiniTest.expect.equality(child.lua_get([[adf.content[1].type]]), "table")
  MiniTest.expect.equality(child.lua_get([[#adf.content[1].content]]), 2)
end

T["util"]["markdown_to_adf"]["should handle code block"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[
    md = "```\nfunction test() {\n  return true;\n}\n```"
    adf = M.markdown_to_adf(md)
  ]])
  MiniTest.expect.equality(child.lua_get([[adf.content[1].type]]), "codeBlock")
  MiniTest.expect.equality(child.lua_get([[adf.content[1].content[1].text:find("function")]]), 1)
end

T["util"]["adf_to_markdown"] = MiniTest.new_set()

T["util"]["adf_to_markdown"]["should convert task list to markdown"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[
    adf = {
      type = "doc",
      version = 1,
      content = {
        {
          type = "taskList",
          content = {
            {
              type = "taskItem",
              attrs = { status = "pending" },
              content = { { type = "paragraph", content = { { type = "text", text = "todo" } } } }
            },
            {
              type = "taskItem",
              attrs = { status = "done" },
              content = { { type = "paragraph", content = { { type = "text", text = "done" } } } }
            }
          }
        }
      }
    }
    md = M.adf_to_markdown(adf)
  ]])
  MiniTest.expect.equality(child.lua_get([[md:find("todo")]]), 4)
  MiniTest.expect.equality(child.lua_get([[md:find("%[ %]")]]), 1)
  MiniTest.expect.equality(child.lua_get([[md:find("%[x%]")]]), 15)
end

T["util"]["adf_to_markdown"]["should convert table to markdown"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[
    adf = {
      type = "doc",
      version = 1,
      content = {
        {
          type = "table",
          content = {
            {
              type = "tableRow",
              content = {
                { type = "tableCell", content = { { type = "paragraph", content = { { type = "text", text = "h1" } } } } },
                { type = "tableCell", content = { { type = "paragraph", content = { { type = "text", text = "h2" } } } } }
              }
            },
            {
              type = "tableRow",
              content = {
                { type = "tableCell", content = { { type = "paragraph", content = { { type = "text", text = "c1" } } } } },
                { type = "tableCell", content = { { type = "paragraph", content = { { type = "text", text = "c2" } } } } }
              }
            }
          }
        }
      }
    }
    md = M.adf_to_markdown(adf)
  ]])
  MiniTest.expect.equality(child.lua_get([[md:find("h1")]]), 3)
  MiniTest.expect.equality(child.lua_get([[md:find("c1")]]), 20)
end



T["util"]["build_issue_tree"] = MiniTest.new_set()

T["util"]["build_issue_tree"]["should handle flat list"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[
    issues = {
      { key = "JIRA-1", summary = "Issue 1" },
      { key = "JIRA-2", summary = "Issue 2" },
    }
    tree = M.build_issue_tree(issues)
  ]])
  MiniTest.expect.equality(child.lua_get([[#tree]]), 2)
  MiniTest.expect.equality(child.lua_get([[tree[1].key]]), "JIRA-1")
  MiniTest.expect.equality(child.lua_get([[tree[2].key]]), "JIRA-2")
  MiniTest.expect.equality(child.lua_get([[#tree[1].children]]), 0)
  MiniTest.expect.equality(child.lua_get([[tree[1].expanded]]), true)
end

T["util"]["build_issue_tree"]["should handle parent-child relationship"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[
    issues = {
      { key = "JIRA-1", summary = "Parent" },
      { key = "JIRA-2", summary = "Child", parent = "JIRA-1" },
    }
    tree = M.build_issue_tree(issues)
  ]])
  MiniTest.expect.equality(child.lua_get([[#tree]]), 1)
  MiniTest.expect.equality(child.lua_get([[tree[1].key]]), "JIRA-1")
  MiniTest.expect.equality(child.lua_get([[#tree[1].children]]), 1)
  MiniTest.expect.equality(child.lua_get([[tree[1].children[1].key]]), "JIRA-2")
end

T["util"]["build_issue_tree"]["should handle deep nesting"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[
    issues = {
      { key = "JIRA-1", summary = "Grandparent" },
      { key = "JIRA-2", summary = "Parent", parent = "JIRA-1" },
      { key = "JIRA-3", summary = "Child", parent = "JIRA-2" },
    }
    tree = M.build_issue_tree(issues)
  ]])
  MiniTest.expect.equality(child.lua_get([[#tree]]), 1)
  MiniTest.expect.equality(child.lua_get([[tree[1].key]]), "JIRA-1")
  MiniTest.expect.equality(child.lua_get([[#tree[1].children]]), 1)
  MiniTest.expect.equality(child.lua_get([[tree[1].children[1].key]]), "JIRA-2")
  MiniTest.expect.equality(child.lua_get([[#tree[1].children[1].children]]), 1)
  MiniTest.expect.equality(child.lua_get([[tree[1].children[1].children[1].key]]), "JIRA-3")
end

T["util"]["build_issue_tree"]["should handle missing parent in list as root"] = function()
  child.lua([[M = require("jira.common.util")]])
  child.lua([[
    issues = {
      { key = "JIRA-2", summary = "Child with missing parent", parent = "JIRA-1" },
    }
    tree = M.build_issue_tree(issues)
  ]])
  MiniTest.expect.equality(child.lua_get([[#tree]]), 1)
  MiniTest.expect.equality(child.lua_get([[tree[1].key]]), "JIRA-2")
end

return T
