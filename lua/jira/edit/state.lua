---@class JiraIssueEdit
---@field key? string
---@field fields table

---@class Jira.Edit.State
---@field issue? JiraIssueEdit
---@field buf? integer
---@field win? integer
---@field valid_components? string[]
---@field valid_sprints? table[]
---@field original_sprint? string
local M = {}

return M
