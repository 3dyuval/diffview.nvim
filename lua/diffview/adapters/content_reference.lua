local oop = require("diffview.oop")

local M = {}

---@enum ContentReferenceType
local ContentReferenceType = oop.enum({
  VCS_COMMIT = 1,
  VCS_STAGE = 2,
  VCS_LOCAL = 3,
  FILESYSTEM = 4,
  CUSTOM = 5,
})

---@class ContentReference : diffview.Object
---@field type ContentReferenceType
---@field identifier string A unique identifier for this content reference
---@field metadata table<string, any> Additional metadata specific to the reference type
local ContentReference = oop.create_class("ContentReference")

---ContentReference constructor
---@param ref_type ContentReferenceType
---@param identifier string
---@param metadata? table<string, any>
function ContentReference:init(ref_type, identifier, metadata)
  assert(ref_type ~= nil, "'ref_type' cannot be nil!")
  assert(type(identifier) == "string" and identifier ~= "", "'identifier' must be a non-empty string!")
  
  self.type = ref_type
  self.identifier = identifier
  self.metadata = metadata or {}
end

function ContentReference:__tostring()
  return self:display_name()
end

---Get a human-readable display name for this content reference
---@return string
function ContentReference:display_name()
  return self.identifier
end

---Check if this reference represents VCS content
---@return boolean
function ContentReference:is_vcs()
  return self.type == ContentReferenceType.VCS_COMMIT 
    or self.type == ContentReferenceType.VCS_STAGE 
    or self.type == ContentReferenceType.VCS_LOCAL
end

---Check if this reference represents filesystem content
---@return boolean
function ContentReference:is_filesystem()
  return self.type == ContentReferenceType.FILESYSTEM
end

---Get the content type as a string
---@return string
function ContentReference:content_type()
  if self.type == ContentReferenceType.VCS_COMMIT then
    return "vcs_commit"
  elseif self.type == ContentReferenceType.VCS_STAGE then
    return "vcs_stage"
  elseif self.type == ContentReferenceType.VCS_LOCAL then
    return "vcs_local"
  elseif self.type == ContentReferenceType.FILESYSTEM then
    return "filesystem"
  elseif self.type == ContentReferenceType.CUSTOM then
    return "custom"
  else
    return "unknown"
  end
end

---Check if two content references are equal
---@param other ContentReference
---@return boolean
function ContentReference:equals(other)
  if not other or type(other) ~= "table" then
    return false
  end
  
  -- Check if other has the required fields (duck typing)
  if not other.type or not other.identifier then
    return false
  end
  
  return self.type == other.type and self.identifier == other.identifier
end

---Get metadata value by key
---@param key string
---@param default? any
---@return any
function ContentReference:get_metadata(key, default)
  return self.metadata[key] or default
end

---Set metadata value
---@param key string
---@param value any
function ContentReference:set_metadata(key, value)
  self.metadata[key] = value
end

---Abstract method: Resolve this reference to actual content
---This should be implemented by subclasses to provide content-specific resolution
---@abstract
---@param adapter any The adapter that can resolve this reference
---@return string[]? content The resolved content lines, or nil if resolution failed
---@return string? error Error message if resolution failed
function ContentReference:resolve_content(adapter)
  oop.abstract_stub()
end

---Abstract method: Get a unique hash for this content reference
---This should be implemented by subclasses for content comparison
---@abstract
---@return string? hash A unique hash representing this content, or nil if unavailable
function ContentReference:content_hash()
  oop.abstract_stub()
end

---Abstract method: Check if the content exists and is accessible
---@abstract
---@param adapter any The adapter that can check this reference
---@return boolean exists True if the content exists and is accessible
function ContentReference:exists(adapter)
  oop.abstract_stub()
end

M.ContentReferenceType = ContentReferenceType
M.ContentReference = ContentReference

return M