local GitAdapter = require("diffview.adapters.vcs.adapters.git").GitAdapter
local HgAdapter = require("diffview.adapters.vcs.adapters.hg").HgAdapter
local FileAdapter = require("diffview.adapters.file").FileAdapter

local M = {}

---@class src.init.get_adapter.Opt
---@field top_indicators string[]?
---@field force_file_adapter boolean? # Force FileAdapter usage (e.g., --no-index flag)
---@field cmd_ctx src.init.get_adapter.Opt.Cmd_Ctx? # Context data from a command call.

---@class src.init.get_adapter.Opt.Cmd_Ctx
---@field path_args string[] # Raw path args
---@field cpath string? # Cwd path given by the `-C` flag option

---@param opt src.init.get_adapter.Opt
---@return string? err
---@return VCSAdapter? adapter
function M.get_adapter(opt)
  if not opt.cmd_ctx then opt.cmd_ctx = {} end

  -- If --no-index flag is present, skip VCS adapters entirely and use FileAdapter
  if opt.force_file_adapter then
    if not FileAdapter.bootstrap.done then FileAdapter.run_bootstrap() end
    if not FileAdapter.bootstrap.ok then
      return "FileAdapter bootstrap failed: " .. (FileAdapter.bootstrap.err or "unknown error")
    end

    local path_args, top_indicators =
      FileAdapter.get_repo_paths(opt.cmd_ctx.path_args, opt.cmd_ctx.cpath)

    if #path_args == 0 then
      return "FileAdapter requires at least 2 file paths for --no-index comparison"
    end

    local err, toplevel = FileAdapter.find_toplevel(top_indicators)
    if err then return "FileAdapter find_toplevel failed: " .. err end

    return FileAdapter.create(toplevel, path_args, opt.cmd_ctx.cpath)
  end

  -- Try VCS adapters first (existing behavior)
  local vcs_adapter_kinds = { GitAdapter, HgAdapter }

  -- Try VCS adapters first
  for _, kind in ipairs(vcs_adapter_kinds) do
    local path_args
    local top_indicators = opt.top_indicators

    if not kind.bootstrap.done then kind.run_bootstrap() end
    if not kind.bootstrap.ok then goto continue end

    if not top_indicators then
      path_args, top_indicators = kind.get_repo_paths(opt.cmd_ctx.path_args, opt.cmd_ctx.cpath)
    end

    local err, toplevel = kind.find_toplevel(top_indicators)

    if not err then
      -- Create a new adapter instance. Store the resolved path args and the
      -- cpath in the adapter context.
      return kind.create(toplevel, path_args, opt.cmd_ctx.cpath)
    end

    ::continue::
  end

  -- If VCS adapters fail, try FileAdapter
  if not FileAdapter.bootstrap.done then FileAdapter.run_bootstrap() end
  if FileAdapter.bootstrap.ok then
    local path_args, top_indicators =
      FileAdapter.get_repo_paths(opt.cmd_ctx.path_args, opt.cmd_ctx.cpath)
    local err, toplevel = FileAdapter.find_toplevel(top_indicators)

    if not err then return FileAdapter.create(toplevel, path_args, opt.cmd_ctx.cpath) end
  end

  return "Not a repo (or any parent), or no supported VCS adapter!"
end

return M
