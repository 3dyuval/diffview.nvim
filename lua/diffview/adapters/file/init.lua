local FileEntry = require("diffview.scene.file_entry").FileEntry
local VCSAdapter = require("diffview.adapters.vcs.adapter").VCSAdapter
local arg_parser = require("diffview.arg_parser")
local async = require("diffview.async")
local config = require("diffview.config")
local lazy = require("diffview.lazy")
local oop = require("diffview.oop")
local utils = require("diffview.utils")
local vcs_utils = require("diffview.adapters.vcs.utils")

local Diff2Hor = lazy.access("diffview.scene.layouts.diff_2_hor", "Diff2Hor") ---@type Diff2Hor|LazyModule
local FileReference = lazy.access("diffview.adapters.file_reference", "FileReference") ---@type FileReference|LazyModule

local api = vim.api
local await, pawait = async.await, async.pawait
local fmt = string.format
local logger = DiffviewGlobal.logger
local pl = lazy.access(utils, "path") ---@type PathLib
local uv = vim.loop

local M = {}

---@class FileAdapter : VCSAdapter
---@operator call : FileAdapter
local FileAdapter = oop.create_class("FileAdapter", VCSAdapter)

FileAdapter.config_key = "file"
FileAdapter.FileReference = FileReference
FileAdapter.bootstrap = {
  done = false,
  ok = false,
  version = {},
  target_version = {
    major = 2,
    minor = 31,
    patch = 0,
  },
}

function FileAdapter.run_bootstrap()
  local git_cmd = config.get_config().git_cmd
  local bs = FileAdapter.bootstrap
  bs.done = true

  local function err(msg)
    if msg then
      bs.err = msg
      logger:error("[FileAdapter] " .. bs.err)
    end
  end

  -- FileAdapter needs git for --no-index functionality
  if vim.fn.executable(git_cmd[1]) ~= 1 then
    return err(fmt("Configured `git_cmd` is not executable: '%s'", git_cmd[1]))
  end

  local out = utils.job(utils.flatten({ git_cmd, "version" }))
  bs.version_string = out[1] and out[1]:match("git version (%S+)") or nil

  if not bs.version_string then return err("Could not get Git version!") end

  -- Parse version string
  local v, target = bs.version, bs.target_version
  bs.target_version_string = fmt("%d.%d.%d", target.major, target.minor, target.patch)
  local parts = vim.split(bs.version_string, "%.")
  v.major = tonumber(parts[1])
  v.minor = tonumber(parts[2]) or 0
  v.patch = tonumber(parts[3]) or 0

  local version_ok = vcs_utils.check_semver(v, target)

  if not version_ok then
    return err(
      string.format(
        "Git version is outdated! Some functionality might not work as expected, "
          .. "or not at all! Current: %s, wanted: %s",
        bs.version_string,
        bs.target_version_string
      )
    )
  end

  bs.ok = true
end

---@param path_args string[] # Raw path args (file paths)
---@param cpath string? # Cwd path given by the `-C` flag option
---@return string[] path_args # Resolved file paths
---@return string[] top_indicators # Top-level indicators (parent directories)
function FileAdapter.get_repo_paths(path_args, cpath)
  local paths = {}
  local top_indicators = {}

  -- For file adapter, we need at least two path arguments for comparison
  if not path_args or #path_args < 2 then return {}, {} end

  -- Resolve file paths
  for _, path_arg in ipairs(path_args) do
    -- Expand tilde and environment variables
    local expanded_path = vim.fn.expand(path_arg)
    expanded_path = pl:readlink(expanded_path) or expanded_path
    local abs_path = pl:absolute(expanded_path, cpath)

    -- Validate path exists
    local file_type = pl:type(abs_path)
    if file_type == nil then return {}, {} end

    table.insert(paths, abs_path)

    -- Add parent directory as top indicator
    if file_type == "file" then
      table.insert(top_indicators, pl:parent(abs_path))
    elseif file_type == "directory" then
      table.insert(top_indicators, abs_path)
    end
  end

  -- Validate file/directory combinations
  if #paths >= 2 then
    local first_type = pl:type(paths[1])
    local second_type = pl:type(paths[2])

    -- git diff --no-index doesn't support file vs directory comparisons
    if
      (first_type == "file" and second_type == "directory")
      or (first_type == "directory" and second_type == "file")
    then
      logger:error("git diff --no-index doesn't support comparing file to directory")
      return {}, {}
    end
  end

  -- Add current directory as fallback
  table.insert(top_indicators, cpath and pl:realpath(cpath) or pl:realpath("."))

  return paths, top_indicators
end

---Try to find the top-level directory for file operations
---@param top_indicators string[] A list of paths that might indicate the working directory
---@return string? err
---@return string toplevel # Absolute path to use as toplevel (common parent or cwd)
function FileAdapter.find_toplevel(top_indicators)
  if not top_indicators or #top_indicators == 0 then return "No path indicators provided", "" end

  -- Use first valid directory as toplevel
  for _, indicator in ipairs(top_indicators) do
    if indicator and pl:is_dir(indicator) then return nil, pl:realpath(indicator) end
  end

  -- Fallback to current directory
  local cwd = pl:realpath(".")
  if pl:is_dir(cwd) then return nil, cwd end

  return "Could not determine a valid toplevel directory", ""
end

---@param toplevel string
---@param path_args string[]
---@param cpath string?
---@return string? err
---@return FileAdapter
function FileAdapter.create(toplevel, path_args, cpath)
  local err
  local adapter = FileAdapter({
    toplevel = toplevel,
    path_args = path_args,
    cpath = cpath,
  })

  if not adapter.ctx.toplevel then
    err = "Could not find the top-level directory!"
  elseif not pl:is_dir(adapter.ctx.toplevel) then
    err = "The top-level is not a readable directory: " .. adapter.ctx.toplevel
  end

  -- For FileAdapter, we don't have a .git directory equivalent
  adapter.ctx.dir = nil

  -- Override file_history_options to be nil for FileAdapter instances
  rawset(adapter, "file_history_options", nil)

  -- Create custom metatable to override file_history_options lookup
  local original_mt = getmetatable(adapter)
  if original_mt and original_mt.__index then
    local original_index = original_mt.__index

    local custom_mt = {}
    for k, v in pairs(original_mt) do
      custom_mt[k] = v
    end

    custom_mt.__index = function(self, key)
      if key == "file_history_options" then return nil end
      if type(original_index) == "function" then
        return original_index(self, key)
      else
        return original_index[key]
      end
    end

    setmetatable(adapter, custom_mt)
  end

  -- Backward compatibility is handled by __index metamethod

  return err, adapter
end

---@param opt vcs.adapter.VCSAdapter.Opt
function FileAdapter:init(opt)
  opt = opt or {}
  self:super(opt)

  self.ctx.toplevel = pl:absolute(opt.toplevel or ".")
  self.ctx.dir = nil -- FileAdapter has no .git directory equivalent
  self.ctx.path_args = opt.path_args or {}
  self.cpath = opt.cpath

  -- FileAdapter doesn't support file history operations - remove inherited method
  rawset(self, "file_history_options", nil)
end

---Get git command for file operations
---@return string[]
function FileAdapter:get_command() return config.get_config().git_cmd end

---Execute a git command synchronously
---@param args string[]
---@param cwd string?
---@return string[] stdout, number code, string[] stderr
function FileAdapter:exec_sync(args, cwd)
  cwd = cwd or self.ctx.toplevel
  return utils.job(utils.flatten({ self:get_command(), args }), cwd)
end

---Get current working directory head (fake revision using timestamp)
---@return string
function FileAdapter:head_rev()
  -- For files, use current timestamp as "revision"
  return tostring(os.time())
end

---Convert revision to git arguments (not used for file adapter)
---@param rev_arg string
---@param path_args string[]
---@return string left_arg, string right_arg, string[] extra_args
function FileAdapter:rev_to_args(rev_arg, path_args)
  -- For file comparisons, we don't use git revisions
  local paths = path_args or self.ctx.path_args
  if #paths >= 2 then
    return paths[1], paths[2], {}
  elseif #paths == 1 then
    -- Compare file to empty
    return "/dev/null", paths[1], {}
  else
    return "/dev/null", "/dev/null", {}
  end
end

---Get options for DiffView
---@param argo ArgObject
---@return table?
function FileAdapter:diffview_options(argo)
  local paths = self.ctx.path_args

  if #paths < 2 then
    utils.err("FileAdapter (--no-index) requires exactly 2 file/directory paths for comparison")
    return nil
  end

  -- Validate file existence (already validated in get_repo_paths, but double-check)
  for _, path in ipairs(paths) do
    if not pl:stat(path) then
      utils.err(fmt("File does not exist: %s", path))
      return nil
    end
  end

  -- Additional validation for file/directory type mismatches
  local first_type = pl:type(paths[1])
  local second_type = pl:type(paths[2])

  if
    (first_type == "file" and second_type == "directory")
    or (first_type == "directory" and second_type == "file")
  then
    utils.err("Cannot compare file to directory with git diff --no-index")
    return nil
  end

  local left, right, extra_args = self:rev_to_args("", paths)

  -- Create options similar to GitAdapter but for file operations
  local selected_file = nil
  if argo and type(argo.get_flag) == "function" then
    selected_file = argo:get_flag("selected-file", { no_empty = true, expand = true })
  end
  
  local options = {
    show_untracked = false, -- File adapter doesn't have untracked files
    selected_file = selected_file
      or (vim.bo.buftype == "" and pl:vim_expand("%:p"))
      or nil,
  }

  return {
    left = left,
    right = right,
    options = options,
  }
end

---Get tracked files using git diff --no-index
---@param left? FileReference Left file reference
---@param right? FileReference Right file reference  
---@param args? string[] Additional arguments
---@param kind? string File kind
---@param opt? table Options
---@return table[] files List of file entries
function FileAdapter:tracked_files(left, right, args, kind, opt)
  args = args or {}
  opt = opt or {}

  local log_opt = { label = "FileAdapter:tracked_files()" }
  logger:debug("tracked_files", log_opt)

  local paths = self.ctx.path_args
  if #paths < 1 then 
    return {}
  end

  -- Create FileReference objects if not provided
  if not left and #paths >= 1 then
    left = FileReference(paths[1])
  end
  if not right and #paths >= 2 then
    right = FileReference(paths[2])
  end

  local cmd_args = { "diff", "--no-index", "--name-status" }

  -- Add paths to compare
  if #paths == 1 then
    -- Compare single file to empty
    vim.list_extend(cmd_args, { "/dev/null", paths[1] })
  else
    -- Compare first two paths
    vim.list_extend(cmd_args, { paths[1], paths[2] })
  end

  local out, code = self:exec_sync(cmd_args)

  if code ~= 0 and code ~= 1 then
    -- git diff --no-index returns 1 when files differ, which is expected
    local err_msg = table.concat(out, "\n")
    logger:error("git diff --no-index failed", { code = code, output = err_msg }, log_opt)
    return {}
  end

  local files = {}
  for _, line in ipairs(out) do
    local status, path = line:match("^([AMDRTUX])\t(.+)$")
    if status and path then
      local file_entry = FileEntry.with_layout(Diff2Hor, {
        adapter = self,
        path = path,
        status = status,
        stats = { additions = 0, deletions = 0 },
        kind = "working",
        revs = {
          a = left,
          b = right,
        },
      })
      table.insert(files, file_entry)
    end
  end

  return files
end

---Get untracked files (always empty for FileAdapter)
FileAdapter.untracked_files = async.wrap(function(self, left, right, opt, callback)
  -- File adapter doesn't have a concept of untracked files
  callback(nil, {})
end)

---Get file blob hash (use file modification time)
---@param path string
---@param rev string?
---@return string?
function FileAdapter:file_blob_hash(path, rev)
  if not pl:is_abs(path) then path = pl:join(self.ctx.toplevel, path) end

  local stat = uv.fs_stat(path)
  if stat then return tostring(stat.mtime.sec) end
  return nil
end

---Check if file is binary (always return false for files)
---@param path string
---@param rev any
---@return boolean
function FileAdapter:is_binary(path, rev)
  return false -- Assume files are not binary for diff purposes
end

---Initialize completion (no-op for files)
function FileAdapter:init_completion()
  -- No completion needed for file adapter
end

---Get revision candidates (empty for files)
---@param arg_lead string
---@param opt? any
---@return string[]
function FileAdapter:rev_candidates(arg_lead, opt) return {} end

---Get log args (not supported for files)
---@param args string[]
---@return string[]
function FileAdapter:get_log_args(args) return {} end

---Get merge context (not supported for files)
---@return any
function FileAdapter:get_merge_context() return nil end

---Restore file (not supported for files)
---@param path string
---@param kind any
---@param commit string
---@return string?
function FileAdapter:restore_file(path, kind, commit) return nil end

---Add files (not supported for files)
---@param paths string[]
---@return boolean
function FileAdapter:add_files(paths) return false end

---Reset files (not supported for files)
---@param paths string[]?
---@return boolean
function FileAdapter:reset_files(paths) return false end

---Show untracked (always false for files)
---@param opt? any
---@return boolean
function FileAdapter:show_untracked(opt) return false end

---Stage index file (not supported for files)
---@param file any
---@return boolean
function FileAdapter:stage_index_file(file) return false end

---Get show args for file content
---@param path string
---@param rev any
---@return string[]
function FileAdapter:get_show_args(path, rev) return { path } end

--[[
Override the default VCS show method to read files directly from filesystem.

This implementation works with both FileReference objects and legacy Rev objects
for backward compatibility. It reads files directly from the filesystem instead
of using git commands.
--]]
---@param path string File path or ignored if ref is FileReference
---@param ref FileReference|Rev? Content reference
---@param callback? fun(stderr: string[]?, stdout: string[]?) Optional callback for async operation
---@return string[]? content File content lines (when called synchronously)
function FileAdapter:show(path, ref, callback)
  local file_path = path
  
  -- Handle FileReference objects
  if ref and type(ref) == "table" then
    if ref.path then
      -- FileReference object
      file_path = ref.path
    elseif ref.commit then
      -- Legacy Rev object with file path in commit field
      file_path = ref.commit
    end
  end

  if not pl:is_abs(file_path) then 
    file_path = pl:join(self.ctx.toplevel, file_path) 
  end

  if not pl:stat(file_path) then
    local error_msg = { "File not found: " .. file_path }
    if callback then
      callback(error_msg, nil)
      return
    else
      return nil
    end
  end

  local ok, content = pcall(vim.fn.readfile, file_path)
  if not ok then
    local error_msg = { "Failed to read file: " .. file_path .. " - " .. tostring(content) }
    if callback then
      callback(error_msg, nil)
      return
    else
      return nil
    end
  end

  if callback then
    callback(nil, content)
  else
    return content
  end
end

-- Export the class
M.FileAdapter = FileAdapter

-- FileAdapter doesn't have file history options - remove method completely after export
FileAdapter.file_history_options = nil
M.FileAdapter.file_history_options = nil

-- Also expose static methods and properties directly on module for convenience
M.find_toplevel = FileAdapter.find_toplevel
M.get_repo_paths = FileAdapter.get_repo_paths
M.run_bootstrap = FileAdapter.run_bootstrap
M.create = FileAdapter.create
M.bootstrap = FileAdapter.bootstrap

-- Export instance methods that tests expect to be available at module level
M.tracked_files = function(self, ...) return FileAdapter.tracked_files(self, ...) end

M.show = function(self, ...) return FileAdapter.show(self, ...) end

M.diffview_options = function(self, ...) return FileAdapter.diffview_options(self, ...) end

return M
