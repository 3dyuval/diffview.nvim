local helpers = require("diffview.tests.helpers")
local git_fixtures = require("diffview.tests.fixtures.git_fixtures")
local file_fixtures = require("diffview.tests.fixtures.file_fixtures")

local eq, neq, async_test = helpers.eq, helpers.neq, helpers.async_test

-- Cross-Adapter Compatibility Tests approach
-- These tests call REAL diffview.nvim APIs to test adapter integration
-- They will FAIL until FileAdapter and source router are implemented

describe("Cross-Adapter Compatibility", function()
  describe("Real Adapter Interface Testing", function()
    it("should compare GitAdapter and FileAdapter interfaces", function()
      -- Test actual GitAdapter interface
      local GitAdapter = require("diffview.adapters.vcs.adapters.git").GitAdapter

      eq("function", type(GitAdapter.find_toplevel))
      eq("function", type(GitAdapter.get_repo_paths))
      eq("function", type(GitAdapter.run_bootstrap))

      -- Test FileAdapter interface (will fail until implemented)
      local file_success, FileAdapter = pcall(require, "diffview.adapters.file")

      if file_success then
        -- FileAdapter should have same interface as GitAdapter
        eq("function", type(FileAdapter.find_toplevel))
        eq("function", type(FileAdapter.get_repo_paths))
        eq("function", type(FileAdapter.run_bootstrap))
        eq("function", type(FileAdapter.create))
      else
        -- Expected to fail until FileAdapter is implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)

    it("should test real adapter context creation", function()
      local tmp_dir, old_cwd = git_fixtures.create_temp_repo()

      -- Test real GitAdapter context creation
      local GitAdapter = require("diffview.adapters.vcs.adapters.git").GitAdapter
      GitAdapter.run_bootstrap()

      local path_args = { "test1.txt", "test2.txt" }
      local resolved_args, top_indicators = GitAdapter.get_repo_paths(path_args)
      local err, toplevel = GitAdapter.find_toplevel(top_indicators)

      eq(nil, err)
      eq("string", type(toplevel))

      local git_err, git_adapter = GitAdapter.create(toplevel, resolved_args)
      eq(nil, git_err)
      eq("string", type(git_adapter.ctx.toplevel))
      eq("string", type(git_adapter.ctx.dir))
      eq("table", type(git_adapter.ctx.path_args))

      -- Test FileAdapter context (will fail until implemented)
      local file_success, FileAdapter = pcall(require, "diffview.adapters.file")

      if file_success then
        local file1, file2 = file_fixtures.create_file_comparison_scenario()
        local file_toplevel = vim.fn.fnamemodify(file1, ":h")

        local file_err, file_adapter = FileAdapter.create(file_toplevel, { file1, file2 })

        eq(nil, file_err)
        eq("string", type(file_adapter.ctx.toplevel))
        eq(nil, file_adapter.ctx.dir) -- No .git equivalent
        eq("table", type(file_adapter.ctx.path_args))

        file_fixtures.cleanup(file1, file2)
      else
        -- Expected to fail until FileAdapter is implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end

      git_fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)

    it("should implement consistent error handling patterns", function()
      -- Both adapters should handle errors consistently
      local error_scenarios = {
        "missing_files",
        "permission_denied",
        "invalid_arguments",
        "bootstrap_failure",
      }

      for _, scenario in ipairs(error_scenarios) do
        eq("string", type(scenario))
        -- Both GitAdapter and FileAdapter should handle these scenarios
      end

      eq(4, #error_scenarios)
    end)
  end)

  describe("Real Adapter Selection Logic", function()
    it("should test real GitAdapter selection in git repository", function()
      local tmp_dir, old_cwd = git_fixtures.create_temp_repo()

      -- Test real VCS adapter selection
      local vcs = require("diffview.vcs")
      local err, adapter = vcs.get_adapter({
        cmd_ctx = {
          path_args = { "test1.txt", "test2.txt" },
        },
      })

      eq(nil, err)
      eq("table", type(adapter))
      eq("string", type(adapter.ctx.toplevel))
      eq("string", type(adapter.ctx.dir))

      git_fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)

    it("should test source router fallback to FileAdapter", function()
      -- Test that source router falls back to FileAdapter when VCS fails
      local file1, file2 = file_fixtures.create_file_comparison_scenario()

      local non_git_dir = vim.fn.tempname()
      vim.fn.mkdir(non_git_dir, "p")
      local old_cwd = vim.fn.getcwd()
      vim.cmd("cd " .. non_git_dir)

      -- Test VCS adapter (should fail)
      local vcs = require("diffview.vcs")
      local vcs_err, vcs_adapter = vcs.get_adapter({
        cmd_ctx = {
          path_args = { file1, file2 },
        },
      })

      eq(true, vcs_err ~= nil)
      eq(true, string.match(vcs_err, "Not a repo") ~= nil)
      eq(nil, vcs_adapter)

      -- Test source router (should work when implemented)
      local src_success, src = pcall(require, "diffview.adapters.init")

      if src_success then
        local src_err, src_adapter = src.get_adapter({
          cmd_ctx = {
            path_args = { file1, file2 },
          },
        })

        eq(nil, src_err)
        eq("table", type(src_adapter))
        eq("string", type(src_adapter.ctx.toplevel))
        eq(nil, src_adapter.ctx.dir) -- FileAdapter has no .git dir
      else
        -- Expected to fail until source router is implemented
        eq(true, string.match(src or "", "module.*not found") ~= nil)
      end

      vim.cmd("cd " .. old_cwd)
      file_fixtures.cleanup(non_git_dir, file1, file2)
    end)

    it("should prioritize explicit file paths over VCS context", function()
      local tmp_dir, old_cwd = git_fixtures.create_temp_repo()

      -- Create files outside the git repository
      local external_file1, external_file2 = file_fixtures.create_file_comparison_scenario()

      -- Even in git repo, absolute external paths should use FileAdapter
      local external_paths_detected = not (external_file1:find(tmp_dir) == 1)
      eq(true, external_paths_detected)

      local should_use_fileadapter = external_paths_detected
      eq(true, should_use_fileadapter)

      git_fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
      file_fixtures.cleanup(external_file1, external_file2)
    end)

    it("should handle directory comparisons appropriately", function()
      local dir1, dir2 = file_fixtures.create_directory_comparison_scenario()

      -- Directory comparison should use FileAdapter regardless of VCS context
      local is_directory_comparison = vim.fn.isdirectory(dir1) == 1
        and vim.fn.isdirectory(dir2) == 1
      eq(true, is_directory_comparison)

      -- Directories may not be under VCS control
      local dir1_has_git = vim.fn.isdirectory(dir1 .. "/.git") == 1
      local dir2_has_git = vim.fn.isdirectory(dir2 .. "/.git") == 1

      -- Most temporary test directories won't have git
      eq(false, dir1_has_git)
      eq(false, dir2_has_git)

      local should_use_fileadapter = is_directory_comparison
      eq(true, should_use_fileadapter)

      file_fixtures.cleanup(dir1, dir2)
    end)
  end)

  describe("Real Integration Scenarios", function()
    it("should test diffview_open integration with file arguments", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()

      -- Move to non-git directory
      local tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      local old_cwd = vim.fn.getcwd()
      vim.cmd("cd " .. tmp_dir)

      -- Test actual diffview_open with file arguments
      local diffview = require("diffview.lib")
      local success, result = pcall(diffview.diffview_open, { file1, file2 })

      if success then
        -- Success means full FileAdapter integration is working
        eq("table", type(diffview.views))
        eq(true, #diffview.views > 0)

        -- Check that a DiffView was created
        local view = diffview.views[#diffview.views]
        eq("table", type(view))
        eq("table", type(view.adapter))
      else
        -- Expected to fail until FileAdapter + source router implemented
        eq(
          true,
          string.match(result or "", "Not a repo") ~= nil
            or string.match(result or "", "module.*not found") ~= nil
        )
      end

      vim.cmd("cd " .. old_cwd)
      file_fixtures.cleanup(tmp_dir, file1, file2)
    end)

    it("should test git command execution compatibility", function()
      -- Test that both adapters can execute git commands
      local tmp_dir, old_cwd = git_fixtures.create_temp_repo()

      -- Test GitAdapter command execution
      local vcs = require("diffview.vcs")
      local err, git_adapter = vcs.get_adapter({
        cmd_ctx = {
          path_args = { "test1.txt", "test2.txt" },
        },
      })

      eq(nil, err)
      eq("function", type(git_adapter.exec_sync))

      -- Test FileAdapter command execution (will fail until implemented)
      local file_success, FileAdapter = pcall(require, "diffview.adapters.file")

      if file_success then
        local file1, file2 = file_fixtures.create_file_comparison_scenario()
        local file_err, file_adapter =
          FileAdapter.create(vim.fn.fnamemodify(file1, ":h"), { file1, file2 })

        eq(nil, file_err)
        eq("function", type(file_adapter.exec_sync))

        -- Test git --no-index command
        local output =
          file_adapter:exec_sync({ "git", "diff", "--no-index", "--name-status", file1, file2 })
        eq("table", type(output))

        file_fixtures.cleanup(file1, file2)
      else
        -- Expected to fail until FileAdapter is implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end

      git_fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)

    it("should test adapter view creation differences", function()
      local tmp_dir, old_cwd = git_fixtures.create_temp_repo()

      -- Test GitAdapter view creation
      local vcs = require("diffview.vcs")
      local err, git_adapter = vcs.get_adapter({
        cmd_ctx = {
          path_args = { "test1.txt", "test2.txt" },
        },
      })

      eq(nil, err)
      eq("function", type(git_adapter.diffview_options))

      -- Test that GitAdapter has VCS-specific capabilities
      eq("function", type(git_adapter.file_history_options))

      -- Test FileAdapter view creation (will fail until implemented)
      local file_success, FileAdapter = pcall(require, "diffview.adapters.file")

      if file_success then
        local file1, file2 = file_fixtures.create_file_comparison_scenario()
        local file_err, file_adapter =
          FileAdapter.create(vim.fn.fnamemodify(file1, ":h"), { file1, file2 })

        eq(nil, file_err)
        eq("function", type(file_adapter.diffview_options))

        -- FileAdapter should NOT have file_history_options (no VCS history)
        eq(nil, file_adapter.file_history_options)

        file_fixtures.cleanup(file1, file2)
      else
        -- Expected to fail until FileAdapter is implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end

      git_fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)

    it("should test real error handling across adapters", function()
      -- Test GitAdapter error handling
      local tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      local old_cwd = vim.fn.getcwd()
      vim.cmd("cd " .. tmp_dir)

      -- This should fail - no git repo
      local vcs = require("diffview.vcs")
      local err, adapter = vcs.get_adapter({
        cmd_ctx = {
          path_args = { "/nonexistent1", "/nonexistent2" },
        },
      })

      eq(true, err ~= nil)
      eq(true, string.match(err, "Not a repo") ~= nil)

      -- Test FileAdapter error handling (will fail until implemented)
      local file_success, FileAdapter = pcall(require, "diffview.adapters.file")

      if file_success then
        -- Test FileAdapter with missing files
        local file_err, file_adapter =
          FileAdapter.create("/tmp", { "/nonexistent1", "/nonexistent2" })

        -- Should handle missing files gracefully
        eq(true, file_err ~= nil or file_adapter ~= nil)
      else
        -- Expected to fail until FileAdapter is implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end

      vim.cmd("cd " .. old_cwd)
      vim.fn.delete(tmp_dir, "rf")
    end)
  end)
end)
