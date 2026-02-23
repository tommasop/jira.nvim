---@class Jira.Common.Util
local M = {}

---@class JiraIssue
---@field key string
---@field summary string
---@field status string
---@field type string
---@field parent? string
---@field assignee? string
---@field priority? string
---@field time_spent? number
---@field time_estimate? number
---@field story_points? number

---@class JiraIssueNode : JiraIssue
---@field children JiraIssueNode[]
---@field expanded boolean
---@field points? integer
---@field type? string

---@param issues JiraIssue[]
---@return JiraIssueNode[]
function M.build_issue_tree(issues)
  ---@type table<string, JiraIssueNode>
  local key_to_issue = {}

  for _, issue in ipairs(issues) do
    ---@type JiraIssueNode
    local node = vim.tbl_extend("force", issue, {
      children = {},
      expanded = true,
    })

    key_to_issue[node.key] = node
  end

  ---@type JiraIssueNode[]
  local roots = {}

  -- Use original list order to ensure stability
  for _, issue in ipairs(issues) do
    local node = key_to_issue[issue.key]
    -- Only process if not already processed (though key_to_issue is unique by key)
    -- We just need to check if it's a child or root
    if node then
      if node.parent and key_to_issue[node.parent] then
        table.insert(key_to_issue[node.parent].children, node)
      else
        table.insert(roots, node)
      end
    end
  end

  return roots
end

---@param seconds? number
---@return string time
M.format_time = function(seconds)
  if not seconds or seconds <= 0 then
    return "0"
  end

  local hours = seconds / 3600
  -- If it's an integer, don't show .0
  if hours % 1 == 0 then
    return ("%d"):format(hours)
  end
  -- Otherwise show 1 decimal place
  return ("%.1f"):format(hours)
end

---@param node table|string
---@return string parsed_adf
local function parse_adf(node)
  if not node then
    return ""
  end

  -- Handle plain text
  if type(node) == "string" then
    return node
  end

  -- Handle table structure
  if type(node) ~= "table" or vim.tbl_isempty(node) then
    return ""
  end
  if node.type == "hardBreak" then
    return "\n"
  end

  if node.type == "text" then
    local text = node.text or ""
    if not node.marks then
      return text
    end

    for _, mark in ipairs(node.marks) do
      ---@class ValidMarks
      ---@field strong string
      ---@field em string
      ---@field code string
      ---@field strike string
      ---@field link string
      local valid_marks = {
        strong = "**" .. text .. "**",
        em = "_" .. text .. "_",
        code = "`" .. text .. "`",
        strike = "~~" .. text .. "~~",
        link = ("[%s](%s)"):format(text, mark.attrs and mark.attrs.href or ""),
      }

      if vim.list_contains(vim.tbl_keys(valid_marks), mark.type) then
        text = valid_marks[mark.type]
      end
    end
    return text
  end

  if not node.content then
    return ""
  end

  local parts = {}
  for _, child in ipairs(node.content) do
    table.insert(parts, parse_adf(child))
  end
  local joined = table.concat(parts, "")

  if node.type == "paragraph" then
    return joined .. "\n\n"
  end
  if node.type == "heading" then
    return ("#"):rep(node.attrs and node.attrs.level or 1) .. " " .. joined .. "\n\n"
  end
  if node.type == "listItem" then
    return joined
  end
  if node.type == "bulletList" then
    local list_parts = {}
    for _, child in ipairs(node.content) do
      table.insert(list_parts, "- " .. parse_adf(child))
    end
    return table.concat(list_parts, "") .. "\n"
  end
  if node.type == "orderedList" then
    local list_parts = {}
    for i, child in ipairs(node.content) do
      table.insert(list_parts, i .. ". " .. parse_adf(child))
    end
    return table.concat(list_parts, "") .. "\n"
  end
  if node.type == "codeBlock" then
    return "```" .. (node.attrs and node.attrs.language or "") .. "\n" .. joined .. "\n```\n\n"
  end
  if node.type == "blockquote" then
    return "> " .. joined:gsub("\n", "> ") .. "\n\n"
  end
  if node.type == "rule" then
    return "---\n\n"
  end
  if node.type == "taskList" then
    local task_parts = {}
    for _, item in ipairs(node.content or {}) do
      local status = (item.attrs and item.attrs.status == "done") and "[x]" or "[ ]"
      local item_text = ""
      if item.content and #item.content > 0 then
        for _, c in ipairs(item.content) do
          item_text = item_text .. parse_adf(c)
        end
      end
      item_text = item_text:gsub("\n$", ""):gsub("^%s*", "")
      table.insert(task_parts, "- " .. status .. " " .. item_text)
    end
    return table.concat(task_parts, "\n") .. "\n\n"
  end
  if node.type == "taskItem" then
    return joined
  end
  if node.type == "table" then
    if not node.content or #node.content == 0 then
      return ""
    end

    local function get_cell_text(cell)
      if not cell.content then
        return ""
      end
      local texts = {}
      for _, content_item in ipairs(cell.content) do
        local text = parse_adf(content_item)
        text = text:gsub("\n+$", ""):gsub("^\n+", "")
        text = text:gsub("%s+", " ")
        text = text:gsub("^%s+", ""):gsub("%s+$", "")
        table.insert(texts, text)
      end
      return table.concat(texts, " ")
    end

    local rows = {}
    for _, row in ipairs(node.content) do
      if row.type == "tableRow" then
        local row_cells = {}
        for _, cell in ipairs(row.content or {}) do
          table.insert(row_cells, get_cell_text(cell))
        end
        if #row_cells > 0 then
          table.insert(rows, row_cells)
        end
      end
    end

    if #rows == 0 then
      return ""
    end

    local col_count = 0
    for _, row in ipairs(rows) do
      col_count = math.max(col_count, #row)
    end

    local col_widths = {}
    for ci = 1, col_count do
      col_widths[ci] = 0
      for _, row in ipairs(rows) do
        if row[ci] then
          col_widths[ci] = math.max(col_widths[ci], #row[ci])
        end
      end
    end

    local result = {}
    for ri, row in ipairs(rows) do
      local row_parts = {}
      for ci = 1, col_count do
        local cell_text = row[ci] or ""
        local width = col_widths[ci]
        local padding = width - #cell_text
        table.insert(row_parts, cell_text .. string.rep(" ", padding + 1))
      end
      table.insert(result, "| " .. table.concat(row_parts, "| ") .. "|")

      if ri == 1 and #rows > 1 then
        local sep_parts = {}
        for ci = 1, col_count do
          local width = col_widths[ci]
          table.insert(sep_parts, string.rep("-", width + 1))
        end
        table.insert(result, "|-" .. table.concat(sep_parts, "-|-") .. "-|")
      end
    end

    return table.concat(result, "\n") .. "\n\n"
  end
  if node.type == "tableRow" then
    return joined
  end
  if node.type == "tableCell" then
    return joined
  end
  if node.type == "mediaSingle" then
    if node.content and node.content[1] and node.content[1].type == "image" then
      local img = node.content[1]
      local alt = img.attrs and img.attrs.alt or ""
      local url = img.attrs and img.attrs.url or ""
      return "![" .. alt .. "](" .. url .. ")"
    end
  end

  return joined
end

---@param adf? table|string
---@return string
function M.adf_to_markdown(adf)
  if not adf or adf == vim.NIL then
    return ""
  end

  -- Handle plain text (v2 API)
  if type(adf) == "string" then
    return adf
  end

  -- Handle ADF structure (v3 API)
  if type(adf) == "table" then
    return parse_adf(adf)
  end

  return ""
end

function M.strim(s)
  -- Remove leading whitespace
  s = s:gsub("^%s+", "")
  -- Remove trailing whitespace
  s = s:gsub("%s+$", "")
  return s
end

function M.parse_inline_markdown(text)
  local nodes = {}
  local pos = 1
  while pos <= #text do
    local s_bold, e_bold = text:find("%*%*.-%*%*", pos)
    local s_italic1, e_italic1 = text:find("%*[^%*]+%*", pos)
    local s_italic2, e_italic2 = text:find("_[^_]+_", pos)
    local s_strike, e_strike = text:find("~~.-~~", pos)
    local s_code, e_code = text:find("`[^`]+`", pos)
    local s_link, e_link = text:find("%[.-%]%(.-%)", pos)
    local s_img, e_img = text:find("!%[.-%]%([^%)]+%)", pos)

    local match_type = nil
    local start_idx, end_idx

    local candidates = {
      { type = "bold", s = s_bold, e = e_bold },
      { type = "italic_star", s = s_italic1, e = e_italic1 },
      { type = "italic_underscore", s = s_italic2, e = e_italic2 },
      { type = "strike", s = s_strike, e = e_strike },
      { type = "code", s = s_code, e = e_code },
      { type = "link", s = s_link, e = e_link },
      { type = "image", s = s_img, e = e_img },
    }

    local earliest = nil
    for _, cand in ipairs(candidates) do
      if cand.s and (not earliest or cand.s < earliest.s) then
        earliest = cand
      end
    end

    if not earliest then
      table.insert(nodes, { type = "text", text = text:sub(pos) })
      break
    end

    match_type = earliest.type
    start_idx = earliest.s
    end_idx = earliest.e

    if start_idx > pos then
      table.insert(nodes, { type = "text", text = text:sub(pos, start_idx - 1) })
    end

    if match_type == "bold" then
      local content = text:sub(start_idx + 2, end_idx - 2)
      table.insert(nodes, { type = "text", text = content, marks = { { type = "strong" } } })
    elseif match_type == "italic_star" or match_type == "italic_underscore" then
      local content = text:sub(start_idx + 1, end_idx - 1)
      table.insert(nodes, { type = "text", text = content, marks = { { type = "em" } } })
    elseif match_type == "strike" then
      local content = text:sub(start_idx + 2, end_idx - 2)
      table.insert(nodes, { type = "text", text = content, marks = { { type = "strike" } } })
    elseif match_type == "code" then
      local content = text:sub(start_idx + 1, end_idx - 1)
      table.insert(nodes, { type = "text", text = content, marks = { { type = "code" } } })
    elseif match_type == "link" then
      local match = text:sub(start_idx, end_idx)
      local link_text = match:match("%[(.-)%]")
      local link_url = match:match("%((.-)%)")
      table.insert(
        nodes,
        { type = "text", text = link_text, marks = { { type = "link", attrs = { href = link_url } } } }
      )
    elseif match_type == "image" then
      local match = text:sub(start_idx, end_idx)
      local alt_text = match:match("%[!%[(.-)%]%]")
      local img_url = match:match("%((.-)%)")
      table.insert(nodes, {
        type = "image",
        attrs = { alt = alt_text, url = img_url },
      })
    end

    pos = end_idx + 1
  end

  if #nodes == 0 then
    table.insert(nodes, { type = "text", text = "" })
  end

  return nodes
end

---@param text string
---@return table adf
function M.markdown_to_adf(text)
  local doc = {
    type = "doc",
    version = 1,
    content = {},
  }

  local lines = vim.split(text, "\n")

  local state = {
    in_code_block = false,
    code_language = nil,
    code_lines = {},
    in_blockquote = false,
    blockquote_lines = {},
    in_table = false,
    table_headers = {},
    table_rows = {},
    list_type = nil,
    list_items = {},
    paragraph_lines = {},
  }

  local function flush_paragraph()
    if #state.paragraph_lines > 0 then
      local full_text = table.concat(state.paragraph_lines, " ")
      if full_text ~= "" then
        table.insert(doc.content, {
          type = "paragraph",
          content = M.parse_inline_markdown(full_text),
        })
      end
      state.paragraph_lines = {}
    end
  end

  local function flush_list()
    if #state.list_items > 0 and state.list_type then
      local list_node = { type = state.list_type, content = {} }
      for _, item_text in ipairs(state.list_items) do
        table.insert(list_node.content, {
          type = "listItem",
          content = { { type = "paragraph", content = M.parse_inline_markdown(item_text) } },
        })
      end
      table.insert(doc.content, list_node)
      state.list_items = {}
      state.list_type = nil
    end
  end

  local function flush_table()
    if #state.table_headers > 0 then
      local table_node = { type = "table", attrs = { layout = "default" }, content = {} }
      local header_row = { type = "tableRow", content = {} }
      for _, header in ipairs(state.table_headers) do
        table.insert(header_row.content, {
          type = "tableCell",
          content = { { type = "paragraph", content = M.parse_inline_markdown(header) } },
        })
      end
      table.insert(table_node.content, header_row)

      for _, row in ipairs(state.table_rows) do
        local row_node = { type = "tableRow", content = {} }
        for _, cell in ipairs(row) do
          table.insert(row_node.content, {
            type = "tableCell",
            content = { { type = "paragraph", content = M.parse_inline_markdown(cell) } },
          })
        end
        table.insert(table_node.content, row_node)
      end

      table.insert(doc.content, table_node)
      state.table_headers = {}
      state.table_rows = {}
      state.in_table = false
    end
  end

  local function parse_table_cells(line)
    local cells = {}
    line = line:match("^%s*(.*)%s*$")
    if line:sub(1, 1) == "|" then
      line = line:sub(2)
    end
    local i = 1
    while i <= #line do
      if line:sub(i, i) == "|" then
        table.insert(cells, "")
        i = i + 1
      else
        local j = i
        while j <= #line and line:sub(j, j) ~= "|" do
          j = j + 1
        end
        local cell = line:sub(i, j - 1):match("^%s*(.-)%s*$") or ""
        table.insert(cells, cell)
        i = j + 1
      end
    end
    while #cells > 0 and cells[#cells] == "" do
      table.remove(cells)
    end
    return cells
  end

  for _, line in ipairs(lines) do
    if state.in_code_block then
      if line:match("^%s*```%s*$") then
        table.insert(doc.content, {
          type = "codeBlock",
          attrs = { language = state.code_language },
          content = { { type = "text", text = table.concat(state.code_lines, "\n") } },
        })
        state.in_code_block = false
        state.code_lines = {}
        state.code_language = nil
      else
        table.insert(state.code_lines, line)
      end
    elseif state.in_blockquote then
      local quote = line:match("^>%s*(.*)")
      if quote then
        table.insert(state.blockquote_lines, quote)
      else
        local content = table.concat(state.blockquote_lines, "\n")
        if content ~= "" then
          table.insert(doc.content, {
            type = "blockquote",
            content = { { type = "paragraph", content = M.parse_inline_markdown(content) } },
          })
        end
        state.in_blockquote = false
        state.blockquote_lines = {}
        if line ~= "" then
          table.insert(state.paragraph_lines, line)
        end
      end
    elseif state.in_table then
      if line:match("^%|") then
        if not line:match("^%|?%s*[-:]+") then
          local cells = parse_table_cells(line)
          if #cells > 0 then
            table.insert(state.table_rows, cells)
          end
        end
      else
        flush_table()
        if line ~= "" then
          table.insert(state.paragraph_lines, line)
        end
      end
    else
      if line:match("^%s*```%w*%s*$") then
        flush_paragraph()
        flush_list()
        flush_table()
        state.in_code_block = true
        local lang = line:match("^%s*```(%w*)")
        state.code_language = lang ~= "" and lang or nil
        state.code_lines = {}
      elseif line:match("^(#+)%s+(.*)") then
        flush_paragraph()
        flush_list()
        flush_table()
        local level, content = line:match("^(#+)%s+(.*)")
        table.insert(doc.content, {
          type = "heading",
          attrs = { level = #level },
          content = M.parse_inline_markdown(content),
        })
      elseif line:match("^%s*[%-*]%s+%[%s*%]%s+(.*)") or line:match("^%s*[%-*]%s+%[x%]%s+(.*)") then
        flush_paragraph()
        if state.list_type ~= "bulletList" then
          flush_list()
        end
        state.list_type = "bulletList"
        local content = line:match("^%s*[%-*]%s+%[[ x]%]%s+(.*)")
        table.insert(state.list_items, content)
      elseif line:match("^%s*[%-*]%s+(.*)") then
        flush_paragraph()
        if state.list_type ~= "bulletList" then
          flush_list()
        end
        state.list_type = "bulletList"
        local content = line:match("^%s*[%-*]%s+(.*)")
        table.insert(state.list_items, content)
      elseif line:match("^%s*%d+%.%s+(.*)") then
        flush_paragraph()
        if state.list_type ~= "orderedList" then
          flush_list()
        end
        state.list_type = "orderedList"
        local content = line:match("^%s*%d+%.%s+(.*)")
        table.insert(state.list_items, content)
      elseif line:match("^%s*[%-_]{3,}%s*$") then
        flush_paragraph()
        flush_list()
        flush_table()
        table.insert(doc.content, { type = "rule" })
      elseif line:match("^>%s*(.*)") then
        flush_paragraph()
        flush_list()
        flush_table()
        local content = line:match("^>%s*(.*)")
        if content ~= "" then
          state.in_blockquote = true
          state.blockquote_lines = { content }
        end
      elseif line:match("^%|") and not line:match("^%|?%s*[-:]+") then
        flush_paragraph()
        flush_list()
        local cells = parse_table_cells(line)
        if #cells > 0 then
          state.in_table = true
          state.table_headers = cells
          state.table_rows = {}
        end
      elseif line == "" then
        flush_paragraph()
        flush_list()
      else
        if state.list_type then
          flush_list()
        end
        table.insert(state.paragraph_lines, line)
      end
    end
  end

  if state.in_code_block and #state.code_lines > 0 then
    table.insert(doc.content, {
      type = "codeBlock",
      attrs = { language = state.code_language },
      content = { { type = "text", text = table.concat(state.code_lines, "\n") } },
    })
  end

  if state.in_blockquote and #state.blockquote_lines > 0 then
    local content = table.concat(state.blockquote_lines, "\n")
    if content ~= "" then
      table.insert(doc.content, {
        type = "blockquote",
        content = { { type = "paragraph", content = M.parse_inline_markdown(content) } },
      })
    end
  end

  flush_table()
  flush_paragraph()
  flush_list()

  if #doc.content == 0 then
    table.insert(doc.content, { type = "paragraph", content = { { type = "text", text = "" } } })
  end

  return doc
end

---@param groups string[]
---@param attr string
---@return string|nil color
function M.get_theme_color(groups, attr)
  for _, g in ipairs(groups) do
    local hl = vim.api.nvim_get_hl(0, { name = g, link = false })
    if hl and hl[attr] then
      return ("#%06x"):format(hl[attr])
    end
  end
end

function M.get_palette()
  return {
    M.get_theme_color({ "DiagnosticOk", "String", "DiffAdd" }, "fg") or "#a6e3a1", -- Green
    M.get_theme_color({ "DiagnosticInfo", "Function", "DiffChange" }, "fg") or "#89b4fa", -- Blue
    M.get_theme_color({ "DiagnosticWarn", "WarningMsg", "Todo" }, "fg") or "#f9e2af", -- Yellow
    M.get_theme_color({ "DiagnosticError", "ErrorMsg", "DiffDelete" }, "fg") or "#f38ba8", -- Red
    M.get_theme_color({ "Special", "Constant" }, "fg") or "#cba6f7", -- Magenta
    M.get_theme_color({ "Identifier", "PreProc" }, "fg") or "#89dceb", -- Cyan
    M.get_theme_color({ "Cursor", "CursorIM" }, "fg") or "#524f67", -- Grey
  }
end

function M.setup_static_highlights()
  ---@type table<string, vim.api.keyset.highlight>
  local hl = {
    JiraTopLevel = { link = "CursorLineNr", bold = true },
    JiraSubTask = { link = "Identifier" },
    JiraStoryPoint = { link = "Error", bold = true },
    JiraAssignee = { link = "MoreMsg" },
    JiraAssigneeUnassigned = { link = "Comment", italic = true },
    exgreen = { fg = "#a6e3a1" },
    JiraProgressBar = { link = "Function" },
    JiraStatus = { link = "lualine_a_insert" },
    JiraStatusRoot = { link = "lualine_a_insert", bold = true },
    JiraTabActive = { link = "CurSearch", bold = true },
    JiraTabInactive = { link = "Search" },
    JiraSubTabActive = { link = "Visual", bold = true },
    JiraSubTabInactive = { link = "StatusLineNC" },
    JiraHelp = { link = "Comment", italic = true },
    JiraKey = { link = "Special", bold = true },
    JiraIconBug = { fg = "#f38ba8" },
    JiraIconStory = { fg = "#a6e3a1" },
    JiraIconTask = { fg = "#89b4fa" },
    JiraIconSubTask = { fg = "#94e2d5" },
    JiraIconTest = { fg = "#fab387" },
    JiraIconDesign = { fg = "#cba6f7" },
    JiraIconOverhead = { fg = "#9399b2" },
    JiraIconImp = { fg = "#89dceb" },
  }

  for name, opts in pairs(hl) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
