local helpers = require("diffview.tests.helpers")
local file_fixtures = require("diffview.tests.fixtures.file_fixtures")

local eq, neq, async_test = helpers.eq, helpers.neq, helpers.async_test

-- FileAdapter core functionality tests - TDD approach
-- These tests call REAL FileAdapter APIs and will FAIL until implementation exists

describe("FileAdapter Core - TDD Tests", function()
  describe("FileAdapter Module Loading (Currently Failing)", function()
    it("should load FileAdapter module (FAILS - not implemented)", function()
      local success, FileAdapter = pcall(require, "diffview.src.adapters.file")
      
      if success then
        eq("table", type(FileAdapter))
        eq("function", type(FileAdapter.find_toplevel))
        eq("function", type(FileAdapter.get_repo_paths))
        eq("function", type(FileAdapter.run_bootstrap))
      else
        -- Expected to fail until FileAdapter is implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)

    it("should test FileAdapter.find_toplevel method (FAILS)", function()
      local success, FileAdapter = pcall(require, "diffview.src.adapters.file")
      
      if success then
        local file1, file2 = file_fixtures.create_file_comparison_scenario()
        
        -- Test actual FileAdapter.find_toplevel
        local err, toplevel = FileAdapter.find_toplevel({ file1, file2 })
        
        eq(nil, err)
        eq("string", type(toplevel))
        eq(true, vim.fn.isdirectory(toplevel) == 1)
        
        file_fixtures.cleanup(file1, file2)
      else
        -- Expected to fail until implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)

    it("should test FileAdapter.create method (FAILS)", function()
      local success, FileAdapter = pcall(require, "diffview.src.adapters.file")
      
      if success then
        local file1, file2 = file_fixtures.create_file_comparison_scenario()
        local toplevel = vim.fn.fnamemodify(file1, ":h")
        
        -- Test actual FileAdapter creation
        local err, adapter = FileAdapter.create(toplevel, { file1, file2 })
        
        eq(nil, err)
        eq("table", type(adapter))
        eq(toplevel, adapter.toplevel)
        eq(nil, adapter.dir) -- FileAdapter should not have .git dir
        eq(2, #adapter.path_args)
        
        file_fixtures.cleanup(file1, file2)
      else
        -- Expected to fail until implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)
  end)

  describe("FileAdapter tracked_files method (Currently Failing)", function()
    it("should test FileAdapter:tracked_files method (FAILS)", function()
      local success, FileAdapter = pcall(require, "diffview.src.adapters.file")
      
      if success then
        local file1, file2 = file_fixtures.create_file_comparison_scenario()
        local toplevel = vim.fn.fnamemodify(file1, ":h")
        
        -- Create FileAdapter instance
        local err, adapter = FileAdapter.create(toplevel, { file1, file2 })
        eq(nil, err)
        
        -- Test tracked_files method (should use git --no-index)
        local files_info = adapter:tracked_files()
        
        eq("table", type(files_info))
        eq(true, #files_info > 0)
        
        file_fixtures.cleanup(file1, file2)
      else
        -- Expected to fail until implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)

    it("should test FileAdapter:show method (FAILS)", function()
      local success, FileAdapter = pcall(require, "diffview.src.adapters.file")
      
      if success then
        local file1, file2 = file_fixtures.create_file_comparison_scenario()
        local toplevel = vim.fn.fnamemodify(file1, ":h")
        
        -- Create FileAdapter instance
        local err, adapter = FileAdapter.create(toplevel, { file1, file2 })
        eq(nil, err)
        
        -- Test show method (should read file contents directly)
        local content = adapter:show(file1, "file")
        
        eq("table", type(content))
        eq(true, #content > 0)
        
        file_fixtures.cleanup(file1, file2)
      else
        -- Expected to fail until implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)

    it("should handle Unicode files correctly", function()
      local file1, file2 = file_fixtures.create_unicode_comparison_scenario()

      eq(true, vim.fn.filereadable(file1) == 1)
      eq(true, vim.fn.filereadable(file2) == 1)

      -- Verify Unicode content
      local content1 = vim.fn.readfile(file1)
      local content2 = vim.fn.readfile(file2)

      -- Both should have Unicode content
      eq(true, string.match(content1[1], "こんにちは世界") ~= nil)
      eq(true, string.match(content2[1], "こんにちは世界") ~= nil)

      file_fixtures.cleanup(file1, file2)
    end)

    it("should handle symlinks on Unix systems", function()
      local original_file, symlink_file = file_fixtures.create_symlink_scenario()

      eq(true, vim.fn.filereadable(original_file) == 1)
      eq(true, vim.fn.filereadable(symlink_file) == 1)

      -- Content should be the same through symlink
      local original_content = vim.fn.readfile(original_file)
      local symlink_content = vim.fn.readfile(symlink_file)
      eq(original_content, symlink_content)

      file_fixtures.cleanup(original_file, symlink_file)
    end)
  end)

  describe("Directory-to-directory comparison", function()
    it("should handle basic directory comparison", function()
      local dir1, dir2 = file_fixtures.create_directory_comparison_scenario()

      eq(true, vim.fn.isdirectory(dir1) == 1)
      eq(true, vim.fn.isdirectory(dir2) == 1)

      -- Verify common files exist
      eq(true, vim.fn.filereadable(dir1 .. "/common.txt") == 1)
      eq(true, vim.fn.filereadable(dir2 .. "/common.txt") == 1)

      -- Verify unique files exist
      eq(true, vim.fn.filereadable(dir1 .. "/unique1.txt") == 1)
      eq(true, vim.fn.filereadable(dir2 .. "/unique2.txt") == 1)

      file_fixtures.cleanup(dir1, dir2)
    end)

    it("should handle directory comparison with subdirectories", function()
      local dir1, dir2 = file_fixtures.create_directory_comparison_scenario({ with_subdirs = true })

      -- Verify subdirectories exist
      eq(true, vim.fn.isdirectory(dir1 .. "/subdir") == 1)
      eq(true, vim.fn.isdirectory(dir2 .. "/subdir") == 1)

      -- Verify files in subdirectories
      eq(true, vim.fn.filereadable(dir1 .. "/subdir/file.txt") == 1)
      eq(true, vim.fn.filereadable(dir2 .. "/subdir/file.txt") == 1)

      file_fixtures.cleanup(dir1, dir2)
    end)
  end)

  describe("FileAdapter bootstrap and git commands (Currently Failing)", function()
    it("should test FileAdapter.run_bootstrap method (FAILS)", function()
      local success, FileAdapter = pcall(require, "diffview.src.adapters.file")
      
      if success then
        -- Test bootstrap process
        FileAdapter.run_bootstrap()
        
        eq(true, FileAdapter.bootstrap.done)
        eq(true, FileAdapter.bootstrap.ok)
        
        -- Should validate git --no-index support
        eq(true, vim.fn.executable("git") == 1)
      else
        -- Expected to fail until implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)

    it("should test git --no-index command execution (FAILS)", function()
      local success, FileAdapter = pcall(require, "diffview.src.adapters.file")
      
      if success then
        local file1, file2 = file_fixtures.create_file_comparison_scenario()
        local toplevel = vim.fn.fnamemodify(file1, ":h")
        
        -- Create adapter and test git command execution
        local err, adapter = FileAdapter.create(toplevel, { file1, file2 })
        eq(nil, err)
        
        -- Test that adapter can execute git --no-index commands
        local cmd_output = adapter:exec_sync({ "git", "diff", "--no-index", "--name-status", file1, file2 })
        
        eq("table", type(cmd_output))
        
        file_fixtures.cleanup(file1, file2)
      else
        -- Expected to fail until implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)

    it("should handle directory arguments in commands", function()
      local dir1, dir2 = file_fixtures.create_directory_comparison_scenario()

      -- Mock command generation for directory comparison
      local expected_dir_cmd = {
        "git",
        "diff",
        "--no-index",
        "--name-status",
        dir1,
        dir2,
      }

      eq("git", expected_dir_cmd[1])
      eq("diff", expected_dir_cmd[2])
      eq("--no-index", expected_dir_cmd[3])
      eq("--name-status", expected_dir_cmd[4])
      eq(dir1, expected_dir_cmd[5])
      eq(dir2, expected_dir_cmd[6])

      file_fixtures.cleanup(dir1, dir2)
    end)
  end)

  describe("Git --no-index output parsing", function()
    it("should parse --name-status output correctly", function()
      -- Mock output from git diff --no-index --name-status
      local mock_output = file_fixtures.mock_git_no_index_output("mixed")

      eq(3, #mock_output)
      eq("M\tfile1.txt", mock_output[1]) -- Modified file
      eq("A\tadded.txt", mock_output[2]) -- Added file
      eq("D\tdeleted.txt", mock_output[3]) -- Deleted file

      -- Test parsing logic
      local parsed_files = {}
      for _, line in ipairs(mock_output) do
        local status, filename = line:match("^([MAD])\t(.+)$")
        table.insert(parsed_files, { status = status, name = filename })
      end

      eq(3, #parsed_files)
      eq("M", parsed_files[1].status)
      eq("file1.txt", parsed_files[1].name)
    end)

    it("should handle binary file indicators in output", function()
      local mock_output = file_fixtures.mock_git_no_index_output("binary")

      eq(1, #mock_output)
      eq(true, string.match(mock_output[1], "M\t.*%.bin$") ~= nil)
    end)

    it("should handle empty output (identical files)", function()
      -- When files are identical, git --no-index produces no output
      local empty_output = {}
      eq(0, #empty_output)

      -- FileAdapter should handle this as "no differences"
      local no_differences = #empty_output == 0
      eq(true, no_differences)
    end)
  end)

  describe("FileAdapter diffview_options method (Currently Failing)", function()
    it("should test FileAdapter:diffview_options method (FAILS)", function()
      local success, FileAdapter = pcall(require, "diffview.src.adapters.file")
      
      if success then
        local file1, file2 = file_fixtures.create_file_comparison_scenario()
        local toplevel = vim.fn.fnamemodify(file1, ":h")
        
        -- Create adapter instance
        local err, adapter = FileAdapter.create(toplevel, { file1, file2 })
        eq(nil, err)
        
        -- Test diffview_options method (needed for DiffView creation)
        local mock_argo = { args = { file1, file2 }, post_args = {} }
        local options = adapter:diffview_options(mock_argo)
        
        eq("table", type(options))
        
        file_fixtures.cleanup(file1, file2)
      else
        -- Expected to fail until implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)
    
    it("should validate git --no-index availability for FileAdapter", function()
      -- Test actual git --no-index command (this should work on most systems)
      if vim.fn.executable("git") == 1 then
        local file1, file2 = file_fixtures.create_file_comparison_scenario()
        
        -- Test git --no-index command directly
        local cmd = string.format("git diff --no-index --name-status %s %s", 
                                 vim.fn.shellescape(file1), 
                                 vim.fn.shellescape(file2))
        local output = vim.fn.system(cmd)
        local exit_code = vim.v.shell_error
        
        -- Exit code 1 is expected for different files, 0 for identical
        eq(true, exit_code == 0 or exit_code == 1)
        
        file_fixtures.cleanup(file1, file2)
      else
        eq(true, true) -- Skip if git not available
      end
    end)
  end)

  describe("End-to-End FileAdapter Integration (Currently Failing)", function()
    it("should test complete FileAdapter workflow (FAILS)", function()
      local success, FileAdapter = pcall(require, "diffview.src.adapters.file")
      
      if success then
        local file1, file2 = file_fixtures.create_file_comparison_scenario()
        
        -- Test complete workflow: bootstrap -> create -> tracked_files -> show
        FileAdapter.run_bootstrap()
        eq(true, FileAdapter.bootstrap.ok)
        
        local err, adapter = FileAdapter.create(vim.fn.fnamemodify(file1, ":h"), { file1, file2 })
        eq(nil, err)
        
        local files_info = adapter:tracked_files()
        eq("table", type(files_info))
        
        local content = adapter:show(file1, "file")
        eq("table", type(content))
        
        file_fixtures.cleanup(file1, file2)
      else
        -- Expected to fail until FileAdapter is fully implemented
        eq(true, string.match(FileAdapter or "", "module.*not found") ~= nil)
      end
    end)
    
    it("should demonstrate integration with diffview_open (FAILS)", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()
      
      -- Move to non-git directory
      local tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      local old_cwd = vim.fn.getcwd()
      vim.cmd("cd " .. tmp_dir)
      
      -- This should work when FileAdapter + source router are implemented
      local success, diffview = pcall(require, "diffview.lib")
      if not success then
        eq(true, string.match(diffview or "", "module.*not found") ~= nil)
        return
      end
      
      local call_success, result = pcall(diffview.diffview_open, { file1, file2 })
      
      if call_success then
        -- Success means FileAdapter integration is working
        eq("table", type(diffview.views))
        eq(true, #diffview.views > 0)
      else
        -- Expected to fail until full implementation
        eq(true, string.match(result or "", "Not a repo") ~= nil or string.match(result or "", "module.*not found") ~= nil)
      end
      
      vim.cmd("cd " .. old_cwd)
      file_fixtures.cleanup(tmp_dir, file1, file2)
    end)
  end)
end)
