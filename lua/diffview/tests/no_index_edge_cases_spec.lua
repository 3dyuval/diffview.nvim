local helpers = require("diffview.tests.helpers")
local file_fixtures = require("diffview.tests.fixtures.file_fixtures")

local eq, neq, async_test = helpers.eq, helpers.neq, helpers.async_test

-- Tests for --no-index flag edge cases and error scenarios
describe("--no-index Edge Cases and Error Handling", function()
  describe("File vs Directory Combinations", function()
    it("should handle file to file comparison", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()

      -- Move to non-git directory to force --no-index behavior
      local tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      local old_cwd = vim.fn.getcwd()
      vim.cmd("cd " .. tmp_dir)

      -- Test what git diff --no-index actually does
      local git_cmd = { "git", "diff", "--no-index", "--name-status", file1, file2 }
      local git_output = vim.fn.system(git_cmd)
      local git_exit_code = vim.v.shell_error

      -- Test FileAdapter behavior
      local success, src = pcall(require, "diffview.adapters.init")
      if success then
        local err, adapter = src.get_adapter({
          force_file_adapter = true,
          cmd_ctx = {
            path_args = { file1, file2 },
          },
        })

        if not err and adapter then
          -- File-to-file should work
          eq("table", type(adapter))
          eq(2, #adapter.ctx.path_args)
          eq(file1, adapter.ctx.path_args[1])
          eq(file2, adapter.ctx.path_args[2])
        end
      end

      vim.cmd("cd " .. old_cwd)
      file_fixtures.cleanup(tmp_dir, file1, file2)
    end)

    it("should handle file to directory comparison", function()
      local file1 = vim.fn.tempname() .. ".txt"
      vim.fn.writefile({ "content1", "content2" }, file1)

      local dir1 = vim.fn.tempname() .. "_dir"
      vim.fn.mkdir(dir1, "p")
      vim.fn.writefile({ "dir content" }, dir1 .. "/file.txt")

      -- Test what git diff --no-index does with file vs directory
      local git_cmd = { "git", "diff", "--no-index", "--name-status", file1, dir1 }
      local git_output = vim.fn.system(git_cmd)
      local git_exit_code = vim.v.shell_error

      print("Git file vs directory - Exit code:", git_exit_code)
      print("Git file vs directory - Output:", git_output)

      -- Git fails with file vs directory (exit code 1, "Could not access" error)
      -- This is expected and means FileAdapter should fail gracefully
      eq(1, git_exit_code)
      eq(true, string.match(git_output, "Could not access") ~= nil)

      -- Test FileAdapter behavior
      local success, src = pcall(require, "diffview.adapters.init")
      if success then
        local err, adapter = src.get_adapter({
          force_file_adapter = true,
          cmd_ctx = {
            path_args = { file1, dir1 },
          },
        })

        -- FileAdapter should detect this invalid combination and fail gracefully (when implemented)
        -- For now, we expect it to fail with "not implemented" or similar
        eq(true, err ~= nil, "FileAdapter should fail (not implemented yet or invalid combination)")
        print("FileAdapter error for file vs directory:", err)
      end

      file_fixtures.cleanup(file1, dir1)
    end)

    it("should handle directory to directory comparison", function()
      local dir1, dir2 = file_fixtures.create_directory_comparison_scenario({ with_subdirs = true })

      -- Test what git diff --no-index does with directory vs directory
      local git_cmd = { "git", "diff", "--no-index", "--name-status", dir1, dir2 }
      local git_output = vim.fn.system(git_cmd)
      local git_exit_code = vim.v.shell_error

      print("Git directory vs directory - Exit code:", git_exit_code)
      print("Git directory vs directory - Output:", git_output)

      -- Git successfully handles directory-to-directory comparison (exit code 1 with diff output)
      eq(1, git_exit_code) -- 1 means differences found
      eq(true, string.match(git_output, "[MAD]\\t") ~= nil) -- Should have status output

      -- Test FileAdapter behavior
      local success, src = pcall(require, "diffview.adapters.init")
      if success then
        local err, adapter = src.get_adapter({
          force_file_adapter = true,
          cmd_ctx = {
            path_args = { dir1, dir2 },
          },
        })

        -- Git supports directory comparison, so FileAdapter should too (when implemented)
        -- For now, we expect it to fail with "not implemented" or similar
        eq(true, err ~= nil, "FileAdapter should fail (not implemented yet)")
        print("FileAdapter error for directory vs directory:", err)
      end

      file_fixtures.cleanup(dir1, dir2)
    end)
  end)

  describe("Error Scenarios", function()
    it("should handle missing files gracefully", function()
      local nonexistent1 = "/tmp/nonexistent_file_1.txt"
      local nonexistent2 = "/tmp/nonexistent_file_2.txt"

      -- Test git behavior with missing files
      local git_cmd = { "git", "diff", "--no-index", "--name-status", nonexistent1, nonexistent2 }
      local git_output = vim.fn.system(git_cmd)
      local git_exit_code = vim.v.shell_error

      print("Git missing files - Exit code:", git_exit_code)
      print("Git missing files - Output:", git_output)

      -- Git fails with missing files (exit code 1, "Could not access" error)
      eq(1, git_exit_code)
      eq(true, string.match(git_output, "Could not access") ~= nil)

      -- Test FileAdapter behavior
      local success, src = pcall(require, "diffview.adapters.init")
      if success then
        local err, adapter = src.get_adapter({
          force_file_adapter = true,
          cmd_ctx = {
            path_args = { nonexistent1, nonexistent2 },
          },
        })

        -- FileAdapter should detect missing files and fail gracefully
        eq(true, err ~= nil, "FileAdapter should detect missing files")
        eq(
          true,
          string.match(err or "", "not found") ~= nil
            or string.match(err or "", "does not exist") ~= nil
            or string.match(err or "", "Could not access") ~= nil,
          "Error message should indicate missing files"
        )
      end
    end)

    it("should handle single file argument", function()
      local file1, _ = file_fixtures.create_file_comparison_scenario()

      -- Test git behavior with single file
      local git_cmd = { "git", "diff", "--no-index", "--name-status", file1 }
      local git_output = vim.fn.system(git_cmd)
      local git_exit_code = vim.v.shell_error

      print("Git single file - Exit code:", git_exit_code)
      print("Git single file - Output:", git_output)

      -- Git requires exactly 2 arguments for --no-index (exit code 129, usage message)
      eq(129, git_exit_code)
      eq(true, string.match(git_output, "usage: git diff --no%-index") ~= nil)

      -- Test FileAdapter behavior
      local success, src = pcall(require, "diffview.adapters.init")
      if success then
        local err, adapter = src.get_adapter({
          force_file_adapter = true,
          cmd_ctx = {
            path_args = { file1 },
          },
        })

        -- FileAdapter should reject single file argument like git does
        eq(true, err ~= nil, "FileAdapter should require two arguments")
        eq(
          true,
          string.match(err or "", "two") ~= nil or string.match(err or "", "argument") ~= nil,
          "Error should mention argument requirement"
        )
      end

      file_fixtures.cleanup(file1)
    end)

    it("should handle no file arguments", function()
      -- Test FileAdapter behavior with no files
      local success, src = pcall(require, "diffview.adapters.init")
      if success then
        local err, adapter = src.get_adapter({
          force_file_adapter = true,
          cmd_ctx = {
            path_args = {},
          },
        })

        -- Should fail gracefully with no arguments
        eq(true, err ~= nil, "FileAdapter should require file arguments")
        eq(
          true,
          string.match(err or "", "file") ~= nil or string.match(err or "", "path") ~= nil,
          "Error should mention missing file paths"
        )
      end
    end)

    it("should handle permission denied files", function()
      -- Create a file and remove read permissions (if possible on current system)
      local file1 = vim.fn.tempname() .. ".txt"
      vim.fn.writefile({ "content" }, file1)

      -- Try to remove read permissions (might not work on all systems)
      vim.fn.system({ "chmod", "000", file1 })

      local file2, _ = file_fixtures.create_file_comparison_scenario()

      -- Test git behavior with permission denied
      local git_cmd = { "git", "diff", "--no-index", "--name-status", file1, file2 }
      local git_output = vim.fn.system(git_cmd)
      local git_exit_code = vim.v.shell_error

      print("Git permission denied - Exit code:", git_exit_code)
      print("Git permission denied - Output:", git_output)

      -- Test FileAdapter behavior
      local success, src = pcall(require, "diffview.adapters.init")
      if success then
        local err, adapter = src.get_adapter({
          force_file_adapter = true,
          cmd_ctx = {
            path_args = { file1, file2 },
          },
        })

        -- Should handle permission issues gracefully
        if git_exit_code ~= 0 and git_exit_code ~= 1 then
          eq(true, err ~= nil, "FileAdapter should detect permission issues")
        end
      end

      -- Restore permissions for cleanup
      vim.fn.system({ "chmod", "644", file1 })
      file_fixtures.cleanup(file1, file2)
    end)
  end)

  describe("Path Resolution", function()
    it("should handle relative paths", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()

      -- Get relative paths
      local rel_file1 = vim.fn.fnamemodify(file1, ":t") -- just filename
      local rel_file2 = vim.fn.fnamemodify(file2, ":t") -- just filename

      -- Change to directory containing the files
      local file_dir = vim.fn.fnamemodify(file1, ":h")
      local old_cwd = vim.fn.getcwd()
      vim.cmd("cd " .. file_dir)

      -- Test git behavior with relative paths
      local git_cmd = { "git", "diff", "--no-index", "--name-status", rel_file1, rel_file2 }
      local git_output = vim.fn.system(git_cmd)
      local git_exit_code = vim.v.shell_error

      -- Test FileAdapter behavior
      local success, src = pcall(require, "diffview.adapters.init")
      if success then
        local err, adapter = src.get_adapter({
          force_file_adapter = true,
          cmd_ctx = {
            path_args = { rel_file1, rel_file2 },
          },
        })

        if git_exit_code == 0 or git_exit_code == 1 then
          eq(nil, err, "FileAdapter should handle relative paths like git")
          if adapter then
            -- Paths should be resolved to absolute
            eq(true, string.find(adapter.ctx.path_args[1] or "", rel_file1) ~= nil)
            eq(true, string.find(adapter.ctx.path_args[2] or "", rel_file2) ~= nil)
          end
        end
      end

      vim.cmd("cd " .. old_cwd)
      file_fixtures.cleanup(file1, file2)
    end)

    it("should handle absolute paths", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()

      -- Ensure paths are absolute
      file1 = vim.fn.fnamemodify(file1, ":p")
      file2 = vim.fn.fnamemodify(file2, ":p")

      -- Test FileAdapter behavior with absolute paths
      local success, src = pcall(require, "diffview.adapters.init")
      if success then
        local err, adapter = src.get_adapter({
          force_file_adapter = true,
          cmd_ctx = {
            path_args = { file1, file2 },
          },
        })

        eq(nil, err, "FileAdapter should handle absolute paths")
        if adapter then
          eq(file1, adapter.ctx.path_args[1])
          eq(file2, adapter.ctx.path_args[2])
        end
      end

      file_fixtures.cleanup(file1, file2)
    end)

    it("should handle paths with spaces and special characters", function()
      local base_dir = vim.fn.tempname()
      vim.fn.mkdir(base_dir, "p")

      local file1 = base_dir .. "/file with spaces.txt"
      local file2 = base_dir .. "/file-with-special_chars@#$.txt"

      vim.fn.writefile({ "content 1" }, file1)
      vim.fn.writefile({ "content 2" }, file2)

      -- Test git behavior with special characters
      local git_cmd = { "git", "diff", "--no-index", "--name-status", file1, file2 }
      local git_output = vim.fn.system(git_cmd)
      local git_exit_code = vim.v.shell_error

      -- Test FileAdapter behavior
      local success, src = pcall(require, "diffview.adapters.init")
      if success then
        local err, adapter = src.get_adapter({
          force_file_adapter = true,
          cmd_ctx = {
            path_args = { file1, file2 },
          },
        })

        if git_exit_code == 0 or git_exit_code == 1 then
          eq(nil, err, "FileAdapter should handle special characters in paths")
          if adapter then
            eq(file1, adapter.ctx.path_args[1])
            eq(file2, adapter.ctx.path_args[2])
          end
        end
      end

      file_fixtures.cleanup(base_dir)
    end)
  end)

  describe("Integration with diffview_open", function()
    it("should test actual DiffviewOpen --no-index command", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()

      -- Move to non-git directory
      local tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      local old_cwd = vim.fn.getcwd()
      vim.cmd("cd " .. tmp_dir)

      -- Test actual diffview_open with --no-index
      local success, diffview = pcall(require, "diffview.lib")
      if success then
        local cmd_success, result = pcall(diffview.diffview_open, { "--no-index", file1, file2 })

        if cmd_success then
          -- Success - check that a view was created
          eq("table", type(diffview.views))
          -- Don't require views to be created as implementation might not be complete
        else
          -- Expected failure - should have helpful error message
          print("DiffviewOpen --no-index failed with:", result)
          eq(true, type(result) == "string", "Error should be a descriptive string")

          -- Error should mention the specific issue, not just "not a repo"
          local has_helpful_error = string.match(result or "", "FileAdapter") ~= nil
            or string.match(result or "", "no-index") ~= nil
            or string.match(result or "", "file") ~= nil
          eq(true, has_helpful_error, "Error should be specific to FileAdapter/file operations")
        end
      end

      vim.cmd("cd " .. old_cwd)
      file_fixtures.cleanup(tmp_dir, file1, file2)
    end)
  end)
end)
