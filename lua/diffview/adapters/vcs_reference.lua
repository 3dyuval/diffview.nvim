local lazy = require("diffview.lazy")
local oop = require("diffview.oop")

local ContentReference = lazy.access("diffview.adapters.content_reference", "ContentReference") ---@type ContentReference|LazyModule
local ContentReferenceType = lazy.access("diffview.adapters.content_reference", "ContentReferenceType") ---@type ContentReferenceType|LazyModule

local M = {}

---@enum VCSReferenceType
local VCSReferenceType = oop.enum({
  LOCAL   = 1,
  COMMIT  = 2,
  STAGE   = 3,
  CUSTOM  = 4,
})

---@class VCSReference : ContentReference
---@field vcs_type VCSReferenceType VCS-specific type (LOCAL, COMMIT, STAGE, CUSTOM)
---@field commit? string A commit SHA
---@field stage? integer A stage number
---@field track_head boolean If true, indicates that the rev should be updated when HEAD changes
local VCSReference = oop.create_class("VCSReference", ContentReference)

---VCSReference constructor
---@param vcs_type VCSReferenceType
---@param revision? string|number Commit SHA or stage number
---@param track_head? boolean
---@param metadata? table<string, any>
function VCSReference:init(vcs_type, revision, track_head, metadata)
  local t = type(revision)
  
  assert(
    revision == nil or t == "string" or t == "number",
    "'revision' must be one of: nil, string, number!"
  )
  if t == "string" then
    assert(revision ~= "", "'revision' cannot be an empty string!")
  elseif t == "number" then
    assert(
      revision >= 0 and revision <= 3,
      "'revision' must be a valid stage number ([0-3])!"
    )
  end

  t = type(track_head)
  assert(t == "boolean" or t == "nil", "'track_head' must be of type boolean!")

  -- Map VCS types to ContentReference types
  local content_type
  if vcs_type == VCSReferenceType.COMMIT then
    content_type = ContentReferenceType.VCS_COMMIT
  elseif vcs_type == VCSReferenceType.STAGE then
    content_type = ContentReferenceType.VCS_STAGE
  elseif vcs_type == VCSReferenceType.LOCAL then
    content_type = ContentReferenceType.VCS_LOCAL
  else
    content_type = ContentReferenceType.CUSTOM
  end
  
  -- Create identifier from revision
  local identifier
  if type(revision) == "string" then
    identifier = revision
  elseif type(revision) == "number" then
    identifier = "stage:" .. tostring(revision)
  elseif vcs_type == VCSReferenceType.LOCAL then
    identifier = "LOCAL"
  elseif vcs_type == VCSReferenceType.CUSTOM then
    identifier = "CUSTOM"
  else
    identifier = "unknown"
  end
  
  ContentReference.init(self, content_type, identifier, metadata or {})
  
  self.vcs_type = vcs_type
  self.track_head = track_head or false

  if type(revision) == "string" then
    ---@cast revision string
    self.commit = revision
  elseif type(revision) == "number" then
    ---@cast revision number
    self.stage = revision
  end
end

---Get a human-readable display name
---@return string
function VCSReference:display_name()
  if self.vcs_type == VCSReferenceType.COMMIT or self.vcs_type == VCSReferenceType.STAGE then
    return self:object_name()
  elseif self.vcs_type == VCSReferenceType.LOCAL then
    return "LOCAL"
  elseif self.vcs_type == VCSReferenceType.CUSTOM then
    return "CUSTOM"
  else
    return self.identifier
  end
end

---Check if this reference exists and is accessible
---@param adapter any VCS adapter that can validate this reference
---@return boolean
function VCSReference:exists(adapter)
  if not adapter then
    return false
  end
  
  -- For LOCAL references, always exists
  if self.vcs_type == VCSReferenceType.LOCAL then
    return true
  end
  
  -- For other types, delegate to adapter
  if adapter.validate_rev then
    return adapter:validate_rev(self)
  end
  
  -- Fallback: assume it exists if we have a commit or stage
  return self.commit ~= nil or self.stage ~= nil
end

---Resolve this reference to actual content
---@param adapter any VCS adapter that can resolve this reference
---@param path? string Optional file path within the revision
---@return string[]? content The resolved content lines, or nil if resolution failed
---@return string? error Error message if resolution failed
function VCSReference:resolve_content(adapter, path)
  if not adapter then
    return nil, "No adapter provided for VCS content resolution"
  end
  
  if not adapter.show then
    return nil, "Adapter does not support content resolution"
  end
  
  -- Use adapter's show method to get content
  local ok, result = pcall(adapter.show, adapter, path or "", self)
  if not ok then
    return nil, "Failed to resolve VCS content: " .. tostring(result)
  end
  
  return result, nil
end

---Get a unique hash for this VCS reference
---@return string? hash A unique hash, or nil if unavailable
function VCSReference:content_hash()
  if self.commit then
    return self.commit
  elseif self.stage ~= nil then
    return "stage:" .. tostring(self.stage)
  elseif self.vcs_type == VCSReferenceType.LOCAL then
    -- For LOCAL, use current timestamp as it changes
    return "local:" .. tostring(os.time())
  else
    return nil
  end
end

---Get an abbreviated commit SHA. Returns `nil` if this VCSReference is not a commit.
---@param length integer|nil
---@return string|nil
function VCSReference:abbrev(length)
  if self.commit then
    return self.commit:sub(1, length or 7)
  end
  return nil
end

---Check if this is a commit reference
---@return boolean
function VCSReference:is_commit()
  return self.vcs_type == VCSReferenceType.COMMIT
end

---Check if this is a stage reference
---@return boolean
function VCSReference:is_stage()
  return self.vcs_type == VCSReferenceType.STAGE
end

---Check if this is a local reference
---@return boolean
function VCSReference:is_local()
  return self.vcs_type == VCSReferenceType.LOCAL
end

---Abstract methods that need to be implemented by VCS-specific subclasses

---@diagnostic disable: unused-local, missing-return

---Get the argument describing the range between the two given revs
---@abstract
---@param rev_from VCSReference|string
---@param rev_to? VCSReference|string
---@return string?
function VCSReference.to_range(rev_from, rev_to) oop.abstract_stub() end

---Create VCSReference from name
---@abstract
---@param name string
---@param adapter? any
---@return VCSReference?
function VCSReference.from_name(name, adapter) oop.abstract_stub() end

---Get earliest commit
---@abstract
---@param adapter any
---@return VCSReference?
function VCSReference.earliest_commit(adapter) oop.abstract_stub() end

---Create a new commit rev with the special empty tree SHA
---@abstract
---@return VCSReference
function VCSReference.new_null_tree() oop.abstract_stub() end

---Determine if this rev is currently the head
---@abstract
---@param adapter any
---@return boolean?
function VCSReference:is_head(adapter) oop.abstract_stub() end

---Get object name
---@abstract
---@param abbrev_len? integer
---@return string
function VCSReference:object_name(abbrev_len) oop.abstract_stub() end

---@diagnostic enable: unused-local, missing-return

M.VCSReferenceType = VCSReferenceType
M.VCSReference = VCSReference

return M