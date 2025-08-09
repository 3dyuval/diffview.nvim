local lazy = require("diffview.lazy")
local oop = require("diffview.oop")

local VCSReference = lazy.access("diffview.adapters.vcs_reference", "VCSReference") ---@type VCSReference|LazyModule
local VCSReferenceType = lazy.access("diffview.adapters.vcs_reference", "VCSReferenceType") ---@type VCSReferenceType|LazyModule

local M = {}

---@enum RevType
local RevType = oop.enum({
  LOCAL   = 1,
  COMMIT  = 2,
  STAGE   = 3,
  CUSTOM  = 4,
})

---@alias RevRange { first: Rev, last: Rev }

---@class Rev : VCSReference
---@field type integer Legacy field for backward compatibility
---@field commit? string A commit SHA.
---@field stage? integer A stage number.
---@field track_head boolean If true, indicates that the rev should be updated when HEAD changes.
local Rev = oop.create_class("Rev", VCSReference)

---Rev constructor - maintains backward compatibility with existing RevType enum
---@param rev_type RevType
---@param revision string|number Commit SHA or stage number.
---@param track_head? boolean
function Rev:init(rev_type, revision, track_head)
  -- Map legacy RevType to VCSReferenceType
  local vcs_type
  if rev_type == RevType.LOCAL then
    vcs_type = VCSReferenceType.LOCAL
  elseif rev_type == RevType.COMMIT then
    vcs_type = VCSReferenceType.COMMIT
  elseif rev_type == RevType.STAGE then
    vcs_type = VCSReferenceType.STAGE
  elseif rev_type == RevType.CUSTOM then
    vcs_type = VCSReferenceType.CUSTOM
  else
    error("Invalid RevType: " .. tostring(rev_type))
  end
  
  -- Initialize parent VCSReference
  VCSReference.init(self, vcs_type, revision, track_head)
  
  -- Maintain legacy field for backward compatibility
  self.type = rev_type
end

function Rev:__tostring()
  -- Delegate to parent's display_name method
  return self:display_name()
end

---@diagnostic disable: unused-local, missing-return

---Get the argument describing the range between the two given revs. If a
---single rev is given, the returned argument describes the *range* of the
---single commit pointed to by that rev.
---@abstract
---@param rev_from Rev|string
---@param rev_to? Rev|string
---@return string?
function Rev.to_range(rev_from, rev_to) oop.abstract_stub() end

---@param name string
---@param adapter? VCSAdapter
---@return Rev?
function Rev.from_name(name, adapter)
  oop.abstract_stub()
end

---@param adapter VCSAdapter
---@return Rev?
function Rev.earliest_commit(adapter)
  oop.abstract_stub()
end

---Create a new commit rev with the special empty tree SHA.
---@return Rev
function Rev.new_null_tree()
  oop.abstract_stub()
end

---Determine if this rev is currently the head.
---@param adapter VCSAdapter
---@return boolean?
function Rev:is_head(adapter)
  oop.abstract_stub()
end

---@param abbrev_len? integer
---@return string
function Rev:object_name(abbrev_len)
  oop.abstract_stub()
end

---@diagnostic enable: unused-local, missing-return

-- abbrev method is inherited from VCSReference

M.RevType = RevType
M.Rev = Rev

return M
