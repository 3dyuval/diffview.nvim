local M = {}

---Create a simple temporary git repository for testing
---@return string tmp_dir, string old_cwd
function M.create_temp_repo()
  local tmp_dir = vim.fn.tempname()
  vim.fn.mkdir(tmp_dir, "p")

  local old_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. tmp_dir)

  -- Initialize git repo
  vim.fn.system("git init")
  vim.fn.system("git config user.name 'Test User'")
  vim.fn.system("git config user.email 'test@example.com'")

  -- Create basic test files
  vim.fn.writefile({ "line1", "line2", "line3" }, "test1.txt")
  vim.fn.writefile({ "content1", "content2" }, "test2.txt")

  vim.fn.system("git add .")
  vim.fn.system("git commit -m 'Initial commit'")

  return tmp_dir, old_cwd
end

---Clean up temporary repository
---@param tmp_dir string
---@param old_cwd string
function M.cleanup_temp_repo(tmp_dir, old_cwd)
  vim.cmd("cd " .. old_cwd)
  vim.fn.delete(tmp_dir, "rf")
end

return M