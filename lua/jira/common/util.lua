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
    local md_table = {}
    local col_widths = {}
    for _, row in ipairs(node.content) do
      local row_cells = {}
      for _, cell in ipairs(row.content or {}) do
        local cell_text = parse_adf(cell):gsub("\n$", "")
        table.insert(row_cells, cell_text)
        local len = #cell_text
        col_widths[#row_cells] = math.max(col_widths[#row_cells] or 0, len)
      end
      if #row_cells > 0 then
        table.insert(md_table, row_cells)
      end
    end
    if #md_table == 0 then
      return ""
    end
    local result = {}
    for ri, row in ipairs(md_table) do
      local row_str = "|"
      for ci, cell in ipairs(row) do
        local pad = col_widths[ci] or 0
        row_str = row_str .. " " .. cell .. string.rep(" ", pad - #cell + 1) .. "|"
      end
      table.insert(result, row_str)
      if ri == 1 then
        local sep = "|"
        for ci = 1, #col_widths do
          sep = sep .. " " .. string.rep("-", col_widths[ci]) .. " |"
        end
        table.insert(result, sep)
      end
    end
    return table.concat(result, "\n") .. "\n\n"
  end
  if node.type == "tableRow" then
    return joined
  end
  if node.type == "tableCell" then
    return joined .. "\n"
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
  local current_node = nil
  local in_code_block = false
  local code_language = nil
  local code_lines = {}
  local in_blockquote = false
  local blockquote_lines = {}
  local table_headers = nil
  local table_aligns = {}
  local table_rows = {}

  local function flush_paragraph()
    if current_node and current_node.type == "paragraph" then
      local text_content = ""
      for _, n in ipairs(current_node.content) do
        if n.type == "text" then
          text_content = text_content .. n.text
        end
      end
      if text_content:match("^%s*$") then
        table.remove(doc.content)
      end
    end
    current_node = nil
  end

  local function flush_table()
    if table_headers then
      local table_node = {
        type = "table",
        attrs = { layout = "default" },
        content = {
          {
            type = "tableRow",
            content = vim.tbl_map(function(h)
              return {
                type = "tableCell",
                content = { { type = "paragraph", content = M.parse_inline_markdown(h) } },
              }
            end, table_headers),
          },
        },
      }
      for _, row in ipairs(table_rows) do
        local row_node = {
          type = "tableRow",
          content = vim.tbl_map(function(cell)
            return {
              type = "tableCell",
              content = { { type = "paragraph", content = M.parse_inline_markdown(cell) } },
            }
          end, row),
        }
        table.insert(table_node.content, row_node)
      end
      table.insert(doc.content, table_node)
      table_headers = nil
      table_rows = {}
      table_aligns = {}
      current_node = nil
    end
  end

  local function parse_table_row(line)
    local cells = {}
    local in_cell = false
    local current_cell = ""
    local i = 1
    line = line:match("^%s*(.*)%s*$")
    if line:sub(1, 1) == "|" then
      line = line:sub(2)
    end
    while i <= #line + 1 do
      if i > #line or line:sub(i, i) == "|" then
        if in_cell then
          table.insert(cells, current_cell:match("^%s*(.-)%s*$") or "")
          current_cell = ""
          in_cell = false
        end
      else
        in_cell = true
        current_cell = current_cell .. line:sub(i, i)
      end
      i = i + 1
    end
    return cells
  end

  for _, line in ipairs(lines) do
    if in_code_block then
      if line:match("^%s*```") then
        table.insert(doc.content, {
          type = "codeBlock",
          attrs = { language = code_language },
          content = {
            {
              type = "text",
              text = table.concat(code_lines, "\n"),
            },
          },
        })
        in_code_block = false
        code_lines = {}
        code_language = nil
        current_node = nil
      else
        table.insert(code_lines, line)
      end
    elseif in_blockquote then
      local quote_content = line:match("^>%s*(.*)")
      if quote_content ~= nil then
        table.insert(blockquote_lines, quote_content)
      else
        local bq_content = table.concat(blockquote_lines, "\n")
        if bq_content ~= "" then
          table.insert(doc.content, {
            type = "blockquote",
            content = {
              {
                type = "paragraph",
                content = M.parse_inline_markdown(bq_content),
              },
            },
          })
        end
        in_blockquote = false
        blockquote_lines = {}
        current_node = nil
      end
    else
      local code_lang = line:match("^%s*```(%w*)")
      local h_level, h_content = line:match("^(#+)%s+(.*)")
      local b_content = line:match("^%s*[%-*]%s+(.*)")
      local task_content = line:match("^%s*[%-*]%s+%[%s*%]%s+(.*)")
      local task_done = line:match("^%s*[%-*]%s+%[x%]%s+(.*)")
      local o_content = line:match("^%s*%d+%.%s+(.*)")
      local hr = line:match("^%s*[%-_*]+%s*$")
      local is_empty = (line == "")
      local bq_start = line:match("^>%s*(.*)")
      local table_sep = line:match("^%|?[-%s:]+%|")

      if code_lang then
        flush_paragraph()
        flush_table()
        in_code_block = true
        code_language = code_lang
        if code_language == "" then
          code_language = nil
        end
        code_lines = {}
      elseif hr then
        flush_paragraph()
        flush_table()
        table.insert(doc.content, { type = "rule" })
        current_node = nil
      elseif bq_start ~= nil and (bq_start ~= "" or #blockquote_lines > 0) then
        flush_paragraph()
        flush_table()
        if bq_start == "" then
          bq_start = " "
        end
        table.insert(blockquote_lines, bq_start)
        in_blockquote = true
      elseif is_empty then
        current_node = nil
      elseif line:match("^%|") then
        local cells = parse_table_row(line)
        if #cells > 0 then
          if line:match("^%|?%s*[-:]+%s*%|") then
            for _, c in ipairs(cells) do
              local align = "start"
              if c:match("^:%s*-+$") or c:match("^-+%s*:$") then
                align = "center"
              elseif c:match("^:%s*-+$") then
                align = "end"
              end
              table.insert(table_aligns, align)
            end
          elseif not table_headers then
            flush_paragraph()
            table_headers = cells
          else
            table.insert(table_rows, cells)
          end
        end
      elseif h_level then
        flush_paragraph()
        flush_table()
        current_node = nil
        table.insert(doc.content, {
          type = "heading",
          attrs = { level = #h_level },
          content = M.parse_inline_markdown(h_content),
        })
      elseif task_content or task_done then
        flush_paragraph()
        flush_table()
        local content = task_content or task_done
        local status = task_done and "done" or "pending"
        local task_item = {
          type = "taskItem",
          attrs = { status = status },
          content = {
            {
              type = "paragraph",
              content = M.parse_inline_markdown(content),
            },
          },
        }
        if not current_node or current_node.type ~= "taskList" then
          current_node = { type = "taskList", content = {} }
          table.insert(doc.content, current_node)
        end
        table.insert(current_node.content, task_item)
      elseif b_content then
        flush_paragraph()
        flush_table()
        if not current_node or current_node.type ~= "bulletList" then
          current_node = { type = "bulletList", content = {} }
          table.insert(doc.content, current_node)
        end
        table.insert(current_node.content, {
          type = "listItem",
          content = {
            {
              type = "paragraph",
              content = M.parse_inline_markdown(b_content),
            },
          },
        })
      elseif o_content then
        flush_paragraph()
        flush_table()
        if not current_node or current_node.type ~= "orderedList" then
          current_node = { type = "orderedList", content = {} }
          table.insert(doc.content, current_node)
        end
        table.insert(current_node.content, {
          type = "listItem",
          content = {
            {
              type = "paragraph",
              content = M.parse_inline_markdown(o_content),
            },
          },
        })
      else
        flush_table()
        if current_node and current_node.type == "paragraph" then
          table.insert(current_node.content, { type = "text", text = " " })
          local nodes = M.parse_inline_markdown(line)
          for _, n in ipairs(nodes) do
            table.insert(current_node.content, n)
          end
        else
          current_node = { type = "paragraph", content = {} }
          table.insert(doc.content, current_node)
          local nodes = M.parse_inline_markdown(line)
          for _, n in ipairs(nodes) do
            table.insert(current_node.content, n)
          end
        end
      end
    end
  end

  -- Handle unclosed code block
  if in_code_block then
    table.insert(doc.content, {
      type = "codeBlock",
      attrs = { language = code_language },
      content = {
        {
          type = "text",
          text = table.concat(code_lines, "\n"),
        },
      },
    })
  end

  -- Handle unclosed blockquote
  if in_blockquote and #blockquote_lines > 0 then
    local bq_content = table.concat(blockquote_lines, "\n")
    if bq_content ~= "" then
      table.insert(doc.content, {
        type = "blockquote",
        content = {
          {
            type = "paragraph",
            content = M.parse_inline_markdown(bq_content),
          },
        },
      })
    end
  end

  -- Handle unclosed table
  flush_table()

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
