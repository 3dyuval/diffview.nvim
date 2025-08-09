local M = {}

---Create temporary files for testing
---@param content1 string[]
---@param content2 string[]
---@return string file1, string file2
function M.create_temp_files(content1, content2)
  local file1 = vim.fn.tempname()
  local file2 = vim.fn.tempname()

  vim.fn.writefile(content1 or { "line1", "line2" }, file1)
  vim.fn.writefile(content2 or { "line1", "modified line2" }, file2)

  return file1, file2
end

---Create temporary directories for testing
---@return string dir1, string dir2
function M.create_temp_dirs()
  local dir1 = vim.fn.tempname()
  local dir2 = vim.fn.tempname()

  vim.fn.mkdir(dir1, "p")
  vim.fn.mkdir(dir2, "p")

  return dir1, dir2
end

---Clean up temporary files/directories
---@param ... string
function M.cleanup(...)
  for _, path in ipairs({ ... }) do
    if vim.fn.isdirectory(path) == 1 then
      vim.fn.delete(path, "rf")
    else
      vim.fn.delete(path)
    end
  end
end

return M

