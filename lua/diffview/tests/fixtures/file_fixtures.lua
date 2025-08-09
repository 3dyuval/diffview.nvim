local M = {}

---Create temporary files with specific content for file-to-file comparison
---@param content1? string[] Content for first file
---@param content2? string[] Content for second file
---@return string file1_path, string file2_path
function M.create_file_comparison_scenario(content1, content2)
  local file1 = vim.fn.tempname() .. ".txt"
  local file2 = vim.fn.tempname() .. ".txt"

  local default_content1 = { "line 1", "line 2", "line 3" }
  local default_content2 = { "line 1", "modified line 2", "line 3", "new line 4" }

  vim.fn.writefile(content1 or default_content1, file1)
  vim.fn.writefile(content2 or default_content2, file2)

  return file1, file2
end

---Create temporary directories with files for directory-to-directory comparison
---@param config? table Configuration options
---@return string dir1_path, string dir2_path
function M.create_directory_comparison_scenario(config)
  config = config or {}
  local base_name = config.base_name or "test_dir"

  local dir1 = vim.fn.tempname() .. "_" .. base_name .. "1"
  local dir2 = vim.fn.tempname() .. "_" .. base_name .. "2"

  vim.fn.mkdir(dir1, "p")
  vim.fn.mkdir(dir2, "p")

  -- Create common files
  vim.fn.writefile({ "common content", "line 2" }, dir1 .. "/common.txt")
  vim.fn.writefile({ "common content", "modified line 2" }, dir2 .. "/common.txt")

  -- Create unique files
  vim.fn.writefile({ "unique to dir1" }, dir1 .. "/unique1.txt")
  vim.fn.writefile({ "unique to dir2" }, dir2 .. "/unique2.txt")

  -- Create subdirectories if requested
  if config.with_subdirs then
    vim.fn.mkdir(dir1 .. "/subdir", "p")
    vim.fn.mkdir(dir2 .. "/subdir", "p")
    vim.fn.writefile({ "subdir content 1" }, dir1 .. "/subdir/file.txt")
    vim.fn.writefile({ "subdir content 2" }, dir2 .. "/subdir/file.txt")
  end

  return dir1, dir2
end

---Create scenario with binary files
---@return string file1, string file2
function M.create_binary_comparison_scenario()
  local file1 = vim.fn.tempname() .. ".bin"
  local file2 = vim.fn.tempname() .. ".bin"

  -- Create binary-like content
  local binary_content1 = {}
  local binary_content2 = {}

  for i = 1, 50 do
    table.insert(binary_content1, string.char(i % 256))
    table.insert(binary_content2, string.char((i + 10) % 256))
  end

  vim.fn.writefile({ table.concat(binary_content1) }, file1, "b")
  vim.fn.writefile({ table.concat(binary_content2) }, file2, "b")

  return file1, file2
end

---Create files with Unicode content and names
---@return string file1, string file2
function M.create_unicode_comparison_scenario()
  local file1 = vim.fn.tempname() .. "_测试文件1.txt"
  local file2 = vim.fn.tempname() .. "_テストファイル2.txt"

  vim.fn.writefile({
    "Unicode content: こんにちは世界",
    "Emoji: 🚀 🔥 ⭐️",
    "Mixed: Hello 世界 🌍",
  }, file1)

  vim.fn.writefile({
    "Unicode content: こんにちは世界",
    "Emoji: 🚀 🔥 ✨", -- Different emoji
    "Mixed: Hello 世界 🌍",
    "Additional: 新しい行",
  }, file2)

  return file1, file2
end

---Create files with permission issues (for error testing)
---@return string file1, string file2
function M.create_permission_test_scenario()
  local file1 = vim.fn.tempname() .. ".txt"
  local file2 = vim.fn.tempname() .. ".txt"

  vim.fn.writefile({ "readable content" }, file1)
  vim.fn.writefile({ "will be unreadable" }, file2)

  -- Make file2 unreadable (Unix systems only)
  if vim.fn.has("unix") == 1 then vim.fn.system("chmod 000 " .. file2) end

  return file1, file2
end

---Create mixed file types scenario
---@return string text_file, string binary_file
function M.create_mixed_types_scenario()
  local text_file = vim.fn.tempname() .. ".txt"
  local binary_file = vim.fn.tempname() .. ".bin"

  vim.fn.writefile({ "This is a text file", "Line 2" }, text_file)

  local binary_content = {}
  for i = 0, 255 do
    table.insert(binary_content, string.char(i))
  end
  vim.fn.writefile({ table.concat(binary_content) }, binary_file, "b")

  return text_file, binary_file
end

---Create large files for performance testing
---@param line_count? number Number of lines to create (default: 1000)
---@return string file1, string file2
function M.create_large_files_scenario(line_count)
  line_count = line_count or 1000
  local file1 = vim.fn.tempname() .. "_large1.txt"
  local file2 = vim.fn.tempname() .. "_large2.txt"

  local content1, content2 = {}, {}

  for i = 1, line_count do
    table.insert(content1, "Line " .. i .. " in file 1")
    -- Make every 10th line different
    if i % 10 == 0 then
      table.insert(content2, "Modified line " .. i .. " in file 2")
    else
      table.insert(content2, "Line " .. i .. " in file 1")
    end
  end

  vim.fn.writefile(content1, file1)
  vim.fn.writefile(content2, file2)

  return file1, file2
end

---Create non-existent file scenario (for error testing)
---@return string existing_file, string missing_file
function M.create_missing_file_scenario()
  local existing_file = vim.fn.tempname() .. ".txt"
  local missing_file = vim.fn.tempname() .. "_missing.txt"

  vim.fn.writefile({ "This file exists" }, existing_file)
  -- Don't create missing_file

  return existing_file, missing_file
end

---Create symlink scenario (Unix only)
---@return string original_file, string symlink_file
function M.create_symlink_scenario()
  local original_file = vim.fn.tempname() .. "_original.txt"
  local symlink_file = vim.fn.tempname() .. "_symlink.txt"

  vim.fn.writefile({ "Original file content" }, original_file)

  if vim.fn.has("unix") == 1 then
    vim.fn.system("ln -s " .. original_file .. " " .. symlink_file)
  else
    -- On Windows, create a regular file that mimics the symlink scenario
    vim.fn.writefile({ "Original file content" }, symlink_file)
  end

  return original_file, symlink_file
end

---Create directory vs file comparison scenario (should be an error)
---@return string file_path, string dir_path
function M.create_mixed_types_error_scenario()
  local file_path = vim.fn.tempname() .. ".txt"
  local dir_path = vim.fn.tempname() .. "_dir"

  vim.fn.writefile({ "This is a file" }, file_path)
  vim.fn.mkdir(dir_path, "p")
  vim.fn.writefile({ "File in directory" }, dir_path .. "/file.txt")

  return file_path, dir_path
end

---Clean up temporary files and directories
---@param ... string Paths to clean up
function M.cleanup(...)
  for _, path in ipairs({ ... }) do
    if vim.fn.isdirectory(path) == 1 then
      vim.fn.delete(path, "rf")
    else
      vim.fn.delete(path)
    end
  end
end

---Mock git --no-index command output for testing
---@param scenario string Scenario type: "modified", "added", "deleted", "binary"
---@return string[] output_lines
function M.mock_git_no_index_output(scenario)
  local outputs = {
    modified = {
      "M\tfile1.txt",
      "M\tcommon.txt",
    },
    added = {
      "A\tunique2.txt",
    },
    deleted = {
      "D\tunique1.txt",
    },
    binary = {
      "M\tbinary.bin",
    },
    mixed = {
      "M\tfile1.txt",
      "A\tadded.txt",
      "D\tdeleted.txt",
    },
  }

  return outputs[scenario] or outputs.modified
end

---Get paths to permanent test files for --no-index testing
---@return string file1_path, string file2_path
function M.get_test_files()
  local fixtures_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
  local file1 = fixtures_dir .. "test_files/file1.txt"
  local file2 = fixtures_dir .. "test_files/file2.txt"
  return file1, file2
end

return M
