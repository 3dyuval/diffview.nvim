-- Debug script for --no-index flag
local src = require("diffview.adapters")

print("Testing --no-index functionality")

-- Test file creation for debugging
local file1 = "/home/yuval/.claude"
local file2 = "/home/yuval/.claude/.claude"

print("File 1:", file1)
print("File 2:", file2)
print("File 1 exists:", vim.fn.filereadable(file1) == 1)
print("File 2 exists:", vim.fn.filereadable(file2) == 1)
print("File 1 is directory:", vim.fn.isdirectory(file1) == 1)
print("File 2 is directory:", vim.fn.isdirectory(file2) == 1)

-- Test adapter creation with --no-index
local err, adapter = src.get_adapter({
  force_file_adapter = true,
  cmd_ctx = {
    path_args = { file1, file2 },
  },
})

print("Error:", err)
print("Adapter:", adapter)
if adapter then
  print("Adapter type:", type(adapter))
  print("Adapter toplevel:", adapter.ctx.toplevel)
  print("Adapter path_args:", vim.inspect(adapter.ctx.path_args))
end

