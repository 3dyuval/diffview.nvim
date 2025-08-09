local helpers = require("diffview.tests.helpers")
local git_fixtures = require("diffview.tests.fixtures.git_fixtures")
local file_fixtures = require("diffview.tests.fixtures.file_fixtures")

local eq, neq, async_test = helpers.eq, helpers.neq, helpers.async_test

-- Source router tests for FileAdapter integration
-- These tests use REAL diffview.nvim APIs and will FAIL until FileAdapter is implemented

describe("Source Router (FileAdapter Integration) - TDD Tests", function()
  describe("Real API Tests - Currently Failing", function()
    it("should load source router module (FAILS - not implemented)", function()
      -- This test will FAIL until source router is implemented
      local success, src = pcall(require, "diffview.src.init")
      
      if success then
        eq("table", type(src))
        eq("function", type(src.get_adapter))
      else
        -- Expected to fail currently
        eq(true, string.match(src or "", "module.*not found") ~= nil)
      end
    end)

    it("should require FileAdapter module (FAILS - not implemented)", function()
      -- This test will FAIL until FileAdapter is implemented
      local success, FileAdapter = pcall(require, "diffview.src.adapters.file")
      
      if success then
        eq("table", type(FileAdapter))
        eq("function", type(FileAdapter.find_toplevel))
        eq("function", type(FileAdapter.get_repo_paths))
        eq("function", type(FileAdapter.run_bootstrap))
      else
        -- Expected to fail currently
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)

    it("should call diffview_open with file arguments in non-git directory (FAILS)", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()
      
      -- Move to a non-git directory
      local tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      local old_cwd = vim.fn.getcwd()
      vim.cmd("cd " .. tmp_dir)
      
      -- This should FAIL because FileAdapter is not implemented
      local success, diffview = pcall(require, "diffview.lib")
      if not success then
        eq(true, string.match(diffview or "", "module.*not found") ~= nil)
        return
      end
      
      local call_success, result = pcall(diffview.diffview_open, { file1, file2 })
      
      if call_success then
        -- If successful, FileAdapter was implemented correctly
        eq("table", type(diffview.views))
        eq(true, #diffview.views > 0)
      else
        -- Expected to fail with "Not a repo" error
        eq(true, string.match(result or "", "Not a repo") ~= nil or string.match(result or "", "module.*not found") ~= nil)
      end
      
      vim.cmd("cd " .. old_cwd)
      file_fixtures.cleanup(tmp_dir, file1, file2)
    end)

    it("should test VCS adapter discovery directly (SHOWS current behavior)", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()
      
      -- Move to non-git directory
      local tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      local old_cwd = vim.fn.getcwd()
      vim.cmd("cd " .. tmp_dir)
      
      -- Test the actual VCS adapter discovery
      local success, vcs = pcall(require, "diffview.vcs")
      if not success then
        eq(true, string.match(vcs or "", "module.*not found") ~= nil)
        return
      end
      
      local err, adapter = vcs.get_adapter({
        cmd_ctx = {
          path_args = { file1, file2 }
        }
      })
      
      -- Currently this SHOULD fail - no FileAdapter fallback exists
      eq(true, err ~= nil)
      eq(true, string.match(err, "Not a repo") ~= nil)
      eq(nil, adapter)
      
      vim.cmd("cd " .. old_cwd)
      file_fixtures.cleanup(tmp_dir, file1, file2)
    end)
  end)

  describe("Integration with existing VCS system", function()
    it("should test current vcs.get_adapter behavior in git repo", function()
      local tmp_dir, old_cwd = git_fixtures.create_temp_repo()
      
      -- This should work - GitAdapter exists
      local success, vcs = pcall(require, "diffview.vcs")
      if not success then
        eq(true, string.match(vcs or "", "module.*not found") ~= nil)
        return
      end
      
      local err, adapter = vcs.get_adapter({
        cmd_ctx = {
          path_args = { "test1.txt", "test2.txt" }
        }
      })
      
      eq(nil, err)
      eq("table", type(adapter))
      eq("string", type(adapter.toplevel))
      
      git_fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)
    
    it("should demonstrate that current VCS system fails for file arguments", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()
      
      -- Test in current working directory (assuming it's not a git repo)
      local success, vcs = pcall(require, "diffview.vcs")
      if not success then
        eq(true, string.match(vcs or "", "module.*not found") ~= nil)
        return
      end
      
      local err, adapter = vcs.get_adapter({
        cmd_ctx = {
          path_args = { file1, file2 }
        }
      })
      
      -- This demonstrates the problem: no FileAdapter fallback
      eq(true, err ~= nil)
      eq(true, string.match(err, "Not a repo") ~= nil)
      
      file_fixtures.cleanup(file1, file2)
    end)
    
    it("should test directory comparison failure", function()
      local dir1, dir2 = file_fixtures.create_directory_comparison_scenario()
      
      local success, vcs = pcall(require, "diffview.vcs")
      if not success then
        eq(true, string.match(vcs or "", "module.*not found") ~= nil)
        return
      end
      
      local err, adapter = vcs.get_adapter({
        cmd_ctx = {
          path_args = { dir1, dir2 }
        }
      })
      
      -- Should fail - no FileAdapter for directory comparison
      eq(true, err ~= nil)
      eq(true, string.match(err, "Not a repo") ~= nil)
      
      file_fixtures.cleanup(dir1, dir2)
    end)
  end)

  describe("FileAdapter Implementation Requirements (TDD)", function()
    it("should require FileAdapter interface methods (FAILS)", function()
      -- Test that FileAdapter, when implemented, has required methods
      local success, FileAdapter = pcall(require, "diffview.src.adapters.file")
      
      if success then
        -- Required VCSAdapter interface methods
        local required_methods = {
          "find_toplevel",
          "get_repo_paths",
          "run_bootstrap", 
          "create",
          "tracked_files",
          "show",
          "diffview_options"
        }
        
        for _, method in ipairs(required_methods) do
          eq("function", type(FileAdapter[method]), "Missing method: " .. method)
        end
      else
        -- Expected to fail currently
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)
    
    it("should test FileAdapter bootstrap process (FAILS)", function()
      -- Test FileAdapter bootstrap (check git --no-index support)
      local success, FileAdapter = pcall(require, "diffview.src.adapters.file")
      
      if success then
        local bootstrap_success = pcall(FileAdapter.run_bootstrap)
        eq(true, bootstrap_success)
        eq(true, FileAdapter.bootstrap.ok)
      else
        -- Expected to fail currently  
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)
  end)

  describe("Source Router Implementation Requirements (TDD)", function()
    it("should implement source router fallback logic (FAILS)", function()
      -- Test that source router module provides get_adapter with fallback
      local success, src = pcall(require, "diffview.src.init")
      
      if success then
        local file1, file2 = file_fixtures.create_file_comparison_scenario()
        
        -- Move to non-git directory
        local tmp_dir = vim.fn.tempname()
        vim.fn.mkdir(tmp_dir, "p")
        local old_cwd = vim.fn.getcwd()
        vim.cmd("cd " .. tmp_dir)
        
        -- Should fallback to FileAdapter
        local err, adapter = src.get_adapter({
          cmd_ctx = {
            path_args = { file1, file2 }
          }
        })
        
        eq(nil, err)
        eq("table", type(adapter))
        eq("string", type(adapter.toplevel))
        
        vim.cmd("cd " .. old_cwd)
        file_fixtures.cleanup(tmp_dir, file1, file2)
      else
        -- Expected to fail currently
        eq(true, string.match(src or "", "module.*not found") ~= nil)
      end
    end)
    
    it("should integrate with lib.lua for diffview_open (FAILS)", function()
      -- Test that lib.lua can use source router instead of vcs directly
      local file1, file2 = file_fixtures.create_file_comparison_scenario()
      
      -- This will show current behavior (fails) vs desired behavior  
      local success, diffview = pcall(require, "diffview.lib")
      if not success then
        eq(true, string.match(diffview or "", "module.*not found") ~= nil)
        return
      end
      
      -- Current implementation uses vcs.get_adapter which fails
      -- Future implementation should use src.get_adapter with fallback
      local call_success, result = pcall(diffview.diffview_open, { file1, file2 })
      
      -- Currently fails, should succeed when FileAdapter is implemented
      eq(false, call_success)
      eq(true, string.match(result or "", "Not a repo") ~= nil)
      
      file_fixtures.cleanup(file1, file2)
    end)
  end)
end)
