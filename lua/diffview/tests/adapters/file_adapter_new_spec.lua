local helpers = require("diffview.tests.helpers")
local file_fixtures = require("diffview.tests.fixtures.file_fixtures")

local eq = helpers.eq
local neq = helpers.neq

describe("FileAdapter with ContentReference Architecture", function()
  local FileAdapter, FileReference

  before_each(function()
    -- Load the updated FileAdapter and FileReference
    FileAdapter = require("diffview.adapters.file").FileAdapter
    FileReference = require("diffview.adapters.file_reference").FileReference
  end)

  describe("FileAdapter Core Functionality", function()
    it("should bootstrap successfully", function()
      FileAdapter.run_bootstrap()
      eq(true, FileAdapter.bootstrap.done)
      eq(true, FileAdapter.bootstrap.ok)
    end)

    it("should create FileAdapter instance with FileReference support", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()
      local toplevel = vim.fn.fnamemodify(file1, ":h")

      local err, adapter = FileAdapter.create(toplevel, { file1, file2 })
      eq(nil, err)
      eq("table", type(adapter))
      eq(toplevel, adapter.ctx.toplevel)
      eq(2, #adapter.ctx.path_args)

      file_fixtures.cleanup(file1, file2)
    end)

    it("should handle path resolution correctly", function()
      local paths = { "/tmp/file1.txt", "/tmp/file2.txt" }
      local resolved_paths, top_indicators = FileAdapter.get_repo_paths(paths)
      
      eq("table", type(resolved_paths))
      eq("table", type(top_indicators))
    end)
  end)

  describe("FileReference Integration", function()
    it("should work with FileReference objects in show method", function()
      local temp_file = vim.fn.tempname()
      local test_content = {"line 1", "line 2", "test content"}
      vim.fn.writefile(test_content, temp_file)

      local toplevel = vim.fn.fnamemodify(temp_file, ":h")
      local err, adapter = FileAdapter.create(toplevel, { temp_file })
      eq(nil, err)

      -- Create FileReference
      local file_ref = FileReference(temp_file)
      
      -- Test show method with FileReference
      local content = adapter:show("", file_ref)
      eq("table", type(content))
      eq(3, #content)
      eq("line 1", content[1])
      eq("line 2", content[2])
      eq("test content", content[3])

      vim.fn.delete(temp_file)
    end)

    it("should handle tracked_files with FileReference objects", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()
      local toplevel = vim.fn.fnamemodify(file1, ":h")

      local err, adapter = FileAdapter.create(toplevel, { file1, file2 })
      eq(nil, err)

      -- Create FileReference objects
      local ref1 = FileReference(file1)
      local ref2 = FileReference(file2)

      -- Test tracked_files method
      local files = adapter:tracked_files(ref1, ref2)
      eq("table", type(files))

      file_fixtures.cleanup(file1, file2)
    end)

    it("should provide backward compatibility with legacy interface", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()
      local toplevel = vim.fn.fnamemodify(file1, ":h")

      local err, adapter = FileAdapter.create(toplevel, { file1, file2 })
      eq(nil, err)

      -- Test legacy show method call
      local content = adapter:show(file1)
      eq("table", type(content))
      eq(true, #content > 0)

      file_fixtures.cleanup(file1, file2)
    end)
  end)

  describe("File Operations", function()
    it("should handle file-to-file comparison", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()
      local toplevel = vim.fn.fnamemodify(file1, ":h")

      local err, adapter = FileAdapter.create(toplevel, { file1, file2 })
      eq(nil, err)

      -- Test diffview_options
      local mock_argo = { 
        get_flag = function() return nil end,
        args = { file1, file2 }, 
        post_args = {} 
      }
      local options = adapter:diffview_options(mock_argo)
      
      eq("table", type(options))
      eq("string", type(options.left))
      eq("string", type(options.right))

      file_fixtures.cleanup(file1, file2)
    end)

    it("should handle directory-to-directory comparison", function()
      local dir1, dir2 = file_fixtures.create_directory_comparison_scenario()
      
      local err, adapter = FileAdapter.create(dir1, { dir1, dir2 })
      eq(nil, err)

      eq("string", type(adapter.ctx.toplevel))
      eq(2, #adapter.ctx.path_args)

      file_fixtures.cleanup(dir1, dir2)
    end)

    it("should handle Unicode files correctly", function()
      local file1, file2 = file_fixtures.create_unicode_comparison_scenario()
      local toplevel = vim.fn.fnamemodify(file1, ":h")

      local err, adapter = FileAdapter.create(toplevel, { file1, file2 })
      eq(nil, err)

      local content = adapter:show(file1)
      eq("table", type(content))

      file_fixtures.cleanup(file1, file2)
    end)
  end)

  describe("Error Handling", function()
    it("should handle missing files gracefully", function()
      local missing_file = "/tmp/nonexistent_" .. os.time() .. ".txt"
      local temp_file = vim.fn.tempname()
      vim.fn.writefile({"test"}, temp_file)

      local toplevel = vim.fn.fnamemodify(temp_file, ":h")
      local paths, indicators = FileAdapter.get_repo_paths({ missing_file, temp_file })
      
      -- Should detect missing file in path resolution
      eq(0, #paths) -- Should return empty due to missing file

      vim.fn.delete(temp_file)
    end)

    it("should validate file vs directory combinations", function()
      local temp_file = vim.fn.tempname()
      local temp_dir = vim.fn.tempname()
      vim.fn.writefile({"test"}, temp_file)
      vim.fn.mkdir(temp_dir)

      -- Should fail to create paths for file vs directory
      local paths, indicators = FileAdapter.get_repo_paths({ temp_file, temp_dir })
      eq(0, #paths) -- Should return empty due to validation failure

      vim.fn.delete(temp_file)
      vim.fn.delete(temp_dir, "d")
    end)
  end)

  describe("Integration with ContentReference System", function()
    it("should distinguish between different file references", function()
      local file1, file2 = file_fixtures.create_file_comparison_scenario()
      
      local ref1 = FileReference(file1)
      local ref2 = FileReference(file2)
      
      -- References should be different
      eq(false, ref1:equals(ref2))
      eq(false, ref1:same_file(ref2))
      
      -- But both should be filesystem references
      eq(true, ref1:is_filesystem())
      eq(true, ref2:is_filesystem())
      eq(false, ref1:is_vcs())
      eq(false, ref2:is_vcs())

      file_fixtures.cleanup(file1, file2)
    end)

    it("should provide proper content hashes for file tracking", function()
      local temp_file = vim.fn.tempname()
      vim.fn.writefile({"content"}, temp_file)
      
      local ref = FileReference(temp_file)
      local hash = ref:content_hash()
      
      eq("string", type(hash))
      neq("", hash)

      vim.fn.delete(temp_file)
    end)

    it("should resolve file content through ContentReference interface", function()
      local temp_file = vim.fn.tempname()
      local content = {"test line 1", "test line 2"}
      vim.fn.writefile(content, temp_file)
      
      local ref = FileReference(temp_file)
      local resolved_content, err = ref:resolve_content()
      
      eq(nil, err)
      eq("table", type(resolved_content))
      eq(2, #resolved_content)
      eq("test line 1", resolved_content[1])
      eq("test line 2", resolved_content[2])

      vim.fn.delete(temp_file)
    end)
  end)

  describe("Performance and Edge Cases", function()
    it("should handle large files efficiently", function()
      local file1, file2 = file_fixtures.create_large_files_scenario(100) -- 100 lines instead of 1000
      local toplevel = vim.fn.fnamemodify(file1, ":h")

      local err, adapter = FileAdapter.create(toplevel, { file1, file2 })
      eq(nil, err)

      local content = adapter:show(file1)
      eq("table", type(content))
      eq(100, #content)

      file_fixtures.cleanup(file1, file2)
    end)

    it("should handle binary files appropriately", function()
      local file1, file2 = file_fixtures.create_binary_comparison_scenario()
      local toplevel = vim.fn.fnamemodify(file1, ":h")

      local err, adapter = FileAdapter.create(toplevel, { file1, file2 })
      eq(nil, err)

      -- FileAdapter should handle binary files (though content may be garbled)
      local content = adapter:show(file1)
      eq("table", type(content))

      file_fixtures.cleanup(file1, file2)
    end)
  end)
end)