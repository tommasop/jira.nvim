local state = {
  buf = nil,
  win = nil,
  dim_win = nil,
  ns = vim.api.nvim_create_namespace("Jira"),
  status_hls = {},

  config = {
    jira = {
      base = os.getenv("JIRA_BASE"),
      email = os.getenv("JIRA_EMAIL"),
      token = os.getenv("JIRA_TOKEN"),
      project = os.getenv("JIRA_PROJECT"),
    }
  }
}

return state
