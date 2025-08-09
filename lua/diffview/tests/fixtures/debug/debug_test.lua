-- Debug test for FileAdapter
local tmp_dir = vim.fn.tempname()
vim.fn.mkdir(tmp_dir, "p")
local old_cwd = vim.fn.getcwd()
vim.cmd("cd " .. tmp_dir)

vim.fn.writefile({ "line 1", "line 2" }, "test1.txt")
vim.fn.writefile({ "line 1", "modified line 2" }, "test2.txt")

-- Test source router
local src = require("diffview.adapters")
local err, adapter = src.get_adapter({
  cmd_ctx = {
    path_args = { "test1.txt", "test2.txt" },
  },
})

print("Source router error:", err)
if adapter then
  print("Adapter type:", type(adapter))
  print("Adapter toplevel:", adapter.ctx.toplevel)
  print("Adapter path_args:", vim.inspect(adapter.ctx.path_args))
end

-- Test adapter diffview_options
if adapter then
  local arg_parser = require("diffview.arg_parser")
  local argo = arg_parser.parse({ "test1.txt", "test2.txt" })

  print("Testing diffview_options with argo:", vim.inspect(argo))
  local opts = adapter:diffview_options(argo)
  print("diffview_options result:", opts)
  if opts then
    print("opts.left:", opts.left)
    print("opts.right:", opts.right)
  end
end

-- Test how diffview_open parses arguments
local config = require("diffview.config")
local arg_parser = require("diffview.arg_parser")
local utils = require("diffview.utils")

local args = { "test1.txt", "test2.txt" }
local default_args = config.get_config().default_args.DiffviewOpen
local argo = arg_parser.parse(utils.flatten({ default_args, args }))

print("Parsed argo.args:", vim.inspect(argo.args))
print("Parsed argo.post_args:", vim.inspect(argo.post_args))
print("Rev arg:", argo.args[1])

-- Test diffview_open
local diffview = require("diffview.lib")
local success, result = pcall(diffview.diffview_open, { "test1.txt", "test2.txt" })

print("Call success:", success)
if success then
  print("Views count:", #diffview.views)
  if #diffview.views > 0 then
    print("View type:", type(diffview.views[1]))
    print("Adapter in view:", type(diffview.views[1].adapter))
  end
else
  print("Error:", result)
end

-- Cleanup
vim.cmd("cd " .. old_cwd)
vim.fn.delete(tmp_dir, "rf")
