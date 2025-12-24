local set_rtp = function()
  local rtp = vim.opt.rtp:get()
  local current_dir = vim.fn.getcwd()
  if not vim.list_contains(rtp, current_dir) then
    vim.opt.rtp:append(current_dir)
  end
  -- Add plenary if not already there (it might be added by --cmd in CI)
  local plenary_dir = current_dir .. "/pack/vendor/start/plenary.nvim"
  if vim.fn.isdirectory(plenary_dir) == 1 and not vim.list_contains(rtp, plenary_dir) then
    vim.opt.rtp:append(plenary_dir)
  end
end

set_rtp()
