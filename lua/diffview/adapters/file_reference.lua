local lazy = require("diffview.lazy")
local oop = require("diffview.oop")
local utils = require("diffview.utils")

local ContentReference = lazy.access("diffview.adapters.content_reference", "ContentReference") ---@type ContentReference|LazyModule
local ContentReferenceType = lazy.access("diffview.adapters.content_reference", "ContentReferenceType") ---@type ContentReferenceType|LazyModule

local pl = lazy.access(utils, "path") ---@type PathLib
local uv = vim.loop

local M = {}

---@class FileReference : ContentReference
---@field path string Absolute path to the file
---@field mtime? number File modification time
---@field size? number File size in bytes
local FileReference = oop.create_class("FileReference", ContentReference)

---FileReference constructor
---@param path string File path (will be made absolute)
---@param metadata? table<string, any> Additional metadata
function FileReference:init(path, metadata)
  assert(type(path) == "string" and path ~= "", "'path' must be a non-empty string!")
  
  -- Make path absolute and resolve symlinks
  local abs_path = pl:absolute(path)
  abs_path = pl:readlink(abs_path) or abs_path
  
  -- Use absolute path as identifier
  ContentReference.init(self, ContentReferenceType.FILESYSTEM, abs_path, metadata)
  
  self.path = abs_path
  
  -- Cache file stats if file exists
  self:_update_stats()
end

---Update cached file statistics
function FileReference:_update_stats()
  local stat = uv.fs_stat(self.path)
  if stat then
    self.mtime = stat.mtime.sec
    self.size = stat.size
    self:set_metadata("type", stat.type)
    self:set_metadata("mode", stat.mode)
  else
    self.mtime = nil
    self.size = nil
    self:set_metadata("type", nil)
    self:set_metadata("mode", nil)
  end
end

---Get a human-readable display name
---@return string
function FileReference:display_name()
  -- Show relative path if possible, otherwise basename
  local cwd = vim.fn.getcwd()
  local rel_path = pl:relative(self.path, cwd)
  
  if rel_path and not rel_path:match("^%.%.") then
    return rel_path
  else
    return pl:basename(self.path)
  end
end

---Get the file extension
---@return string?
function FileReference:extension()
  return pl:extension(self.path)
end

---Get the file basename
---@return string
function FileReference:basename()
  return pl:basename(self.path)
end

---Get the parent directory
---@return string
function FileReference:parent()
  return pl:parent(self.path)
end

---Check if the file exists and is accessible
---@param adapter? any Adapter (not used for filesystem references)
---@return boolean
function FileReference:exists(adapter)
  return pl:stat(self.path) ~= nil
end

---Check if this is a directory
---@return boolean
function FileReference:is_directory()
  return pl:type(self.path) == "directory"
end

---Check if this is a regular file
---@return boolean
function FileReference:is_file()
  return pl:type(self.path) == "file"
end

---Get file modification time
---@return number? mtime Modification time in seconds since epoch, or nil if file doesn't exist
function FileReference:modification_time()
  if not self.mtime then
    self:_update_stats()
  end
  return self.mtime
end

---Get file size
---@return number? size File size in bytes, or nil if file doesn't exist
function FileReference:file_size()
  if not self.size then
    self:_update_stats()
  end
  return self.size
end

---Resolve this reference to actual content
---@param adapter? any Adapter (not used for filesystem references)
---@return string[]? content The file content as lines, or nil if resolution failed
---@return string? error Error message if resolution failed
function FileReference:resolve_content(adapter)
  if not self:exists() then
    return nil, "File does not exist: " .. self.path
  end
  
  if self:is_directory() then
    return nil, "Cannot read directory as file: " .. self.path
  end
  
  local ok, content = pcall(vim.fn.readfile, self.path)
  if not ok then
    return nil, "Failed to read file: " .. self.path .. " - " .. tostring(content)
  end
  
  return content, nil
end

---Get a unique hash for this file reference
---Uses file path and modification time for uniqueness
---@return string? hash A unique hash, or nil if file doesn't exist
function FileReference:content_hash()
  if not self:exists() then
    return nil
  end
  
  local mtime = self:modification_time()
  if not mtime then
    return nil
  end
  
  -- Combine path and mtime for a unique hash
  return vim.fn.sha256(self.path .. ":" .. tostring(mtime))
end

---Check if two FileReference objects point to the same file
---@param other FileReference
---@return boolean
function FileReference:same_file(other)
  if not other or not other.class or other.class.name ~= "FileReference" then
    return false
  end
  
  -- Compare resolved absolute paths
  return self.path == other.path
end

---Create a FileReference from a relative path
---@param rel_path string Relative path
---@param base_dir? string Base directory (defaults to cwd)
---@param metadata? table<string, any> Additional metadata
---@return FileReference
function FileReference.from_relative(rel_path, base_dir, metadata)
  base_dir = base_dir or vim.fn.getcwd()
  local abs_path = pl:join(base_dir, rel_path)
  return FileReference(abs_path, metadata)
end

---Create a FileReference for a temporary file
---@param content string[] File content lines
---@param suffix? string File suffix (e.g., ".txt")
---@param metadata? table<string, any> Additional metadata
---@return FileReference
---@return string temp_path The path to the created temporary file
function FileReference.create_temp(content, suffix, metadata)
  suffix = suffix or ""
  local temp_path = vim.fn.tempname() .. suffix
  
  -- Write content to temporary file
  vim.fn.writefile(content, temp_path)
  
  local ref = FileReference(temp_path, metadata)
  ref:set_metadata("temporary", true)
  
  return ref, temp_path
end

---Clean up temporary file if this reference is marked as temporary
function FileReference:cleanup_temp()
  if self:get_metadata("temporary") and self:exists() then
    vim.fn.delete(self.path)
  end
end

M.FileReference = FileReference

return M