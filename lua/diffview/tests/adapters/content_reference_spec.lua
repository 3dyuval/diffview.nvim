local helpers = require("diffview.tests.helpers")
local file_fixtures = require("diffview.tests.fixtures.file_fixtures")

local eq = helpers.eq
local neq = helpers.neq

describe("ContentReference Abstraction", function()
  local ContentReference, ContentReferenceType
  local FileReference
  local VCSReference, VCSReferenceType

  before_each(function()
    -- Load our new abstraction modules
    local content_ref_module = require("diffview.adapters.content_reference")
    ContentReference = content_ref_module.ContentReference
    ContentReferenceType = content_ref_module.ContentReferenceType

    local file_ref_module = require("diffview.adapters.file_reference")
    FileReference = file_ref_module.FileReference

    local vcs_ref_module = require("diffview.adapters.vcs_reference")
    VCSReference = vcs_ref_module.VCSReference
    VCSReferenceType = vcs_ref_module.VCSReferenceType
  end)

  describe("ContentReference Base Class", function()
    it("should create ContentReference with proper type and identifier", function()
      local ref = ContentReference(ContentReferenceType.FILESYSTEM, "test-file.txt")
      
      eq(ContentReferenceType.FILESYSTEM, ref.type)
      eq("test-file.txt", ref.identifier)
      eq("table", type(ref.metadata))
    end)

    it("should provide type checking methods", function()
      local fs_ref = ContentReference(ContentReferenceType.FILESYSTEM, "file.txt")
      local vcs_ref = ContentReference(ContentReferenceType.VCS_COMMIT, "abc123")

      eq(true, fs_ref:is_filesystem())
      eq(false, fs_ref:is_vcs())

      eq(false, vcs_ref:is_filesystem())
      eq(true, vcs_ref:is_vcs())
    end)

    it("should handle metadata operations", function()
      local ref = ContentReference(ContentReferenceType.FILESYSTEM, "file.txt")
      
      ref:set_metadata("test_key", "test_value")
      eq("test_value", ref:get_metadata("test_key"))
      eq("default", ref:get_metadata("missing_key", "default"))
    end)

    it("should provide proper equality checking", function()
      local ref1 = ContentReference(ContentReferenceType.FILESYSTEM, "file.txt")
      local ref2 = ContentReference(ContentReferenceType.FILESYSTEM, "file.txt")
      local ref3 = ContentReference(ContentReferenceType.FILESYSTEM, "other.txt")

      eq(true, ref1:equals(ref2))
      eq(false, ref1:equals(ref3))
    end)
  end)

  describe("FileReference Implementation", function()
    it("should create FileReference with absolute path", function()
      local temp_file = vim.fn.tempname()
      vim.fn.writefile({"test content"}, temp_file)

      local ref = FileReference(temp_file)
      
      eq(ContentReferenceType.FILESYSTEM, ref.type)
      eq(temp_file, ref.path)
      eq(temp_file, ref.identifier)
      eq(true, ref:exists())

      vim.fn.delete(temp_file)
    end)

    it("should resolve file content correctly", function()
      local temp_file = vim.fn.tempname()
      local test_content = {"line 1", "line 2", "line 3"}
      vim.fn.writefile(test_content, temp_file)

      local ref = FileReference(temp_file)
      local content, err = ref:resolve_content()
      
      eq(nil, err)
      eq("table", type(content))
      eq(3, #content)
      eq("line 1", content[1])
      eq("line 2", content[2])
      eq("line 3", content[3])

      vim.fn.delete(temp_file)
    end)

    it("should handle missing files gracefully", function()
      local missing_file = "/tmp/nonexistent_file_" .. os.time() .. ".txt"
      local ref = FileReference(missing_file)
      
      eq(false, ref:exists())
      
      local content, err = ref:resolve_content()
      eq(nil, content)
      neq(nil, err)
      eq(true, string.match(err, "does not exist") ~= nil)
    end)

    it("should provide file metadata", function()
      local temp_file = vim.fn.tempname()
      vim.fn.writefile({"test"}, temp_file)

      local ref = FileReference(temp_file)
      
      eq("string", type(ref:basename()))
      eq("string", type(ref:parent()))
      eq(true, ref:is_file())
      eq(false, ref:is_directory())
      eq("number", type(ref:modification_time()))

      vim.fn.delete(temp_file)
    end)

    it("should create temporary files", function()
      local content = {"temp line 1", "temp line 2"}
      local ref, temp_path = FileReference.create_temp(content, ".txt")
      
      eq(true, ref:exists())
      eq(true, ref:get_metadata("temporary"))
      eq(temp_path, ref.path)
      
      local read_content, err = ref:resolve_content()
      eq(nil, err)
      eq(2, #read_content)
      eq("temp line 1", read_content[1])

      ref:cleanup_temp()
      eq(false, ref:exists())
    end)
  end)

  describe("VCSReference Implementation", function()
    it("should create VCSReference with proper mapping", function()
      local commit_ref = VCSReference(VCSReferenceType.COMMIT, "abc123")
      local local_ref = VCSReference(VCSReferenceType.LOCAL)
      local stage_ref = VCSReference(VCSReferenceType.STAGE, 1)

      eq(ContentReferenceType.VCS_COMMIT, commit_ref.type)
      eq("abc123", commit_ref.identifier)
      eq("abc123", commit_ref.commit)

      eq(ContentReferenceType.VCS_LOCAL, local_ref.type)
      eq("LOCAL", local_ref.identifier)

      eq(ContentReferenceType.VCS_STAGE, stage_ref.type)
      eq("stage:1", stage_ref.identifier)
      eq(1, stage_ref.stage)
    end)

    it("should provide VCS-specific type checking", function()
      local commit_ref = VCSReference(VCSReferenceType.COMMIT, "abc123")
      local local_ref = VCSReference(VCSReferenceType.LOCAL)
      local stage_ref = VCSReference(VCSReferenceType.STAGE, 1)

      eq(true, commit_ref:is_commit())
      eq(false, commit_ref:is_local())
      eq(false, commit_ref:is_stage())

      eq(false, local_ref:is_commit())
      eq(true, local_ref:is_local())
      eq(false, local_ref:is_stage())

      eq(false, stage_ref:is_commit())
      eq(false, stage_ref:is_local())
      eq(true, stage_ref:is_stage())
    end)

    it("should provide commit abbreviation", function()
      local commit_ref = VCSReference(VCSReferenceType.COMMIT, "abcdef123456789")
      
      eq("abcdef1", commit_ref:abbrev())
      eq("abcdef123", commit_ref:abbrev(9))
      
      local local_ref = VCSReference(VCSReferenceType.LOCAL)
      eq(nil, local_ref:abbrev())
    end)
  end)

  describe("Backward Compatibility", function()
    it("should maintain Rev class compatibility", function()
      local Rev = require("diffview.adapters.vcs.rev").Rev
      local RevType = require("diffview.adapters.vcs.rev").RevType
      
      -- Test that Rev still works as before
      local commit_rev = Rev(RevType.COMMIT, "abc123")
      local local_rev = Rev(RevType.LOCAL)
      
      eq(RevType.COMMIT, commit_rev.type)
      eq("abc123", commit_rev.commit)
      eq("abc123", commit_rev:abbrev(6)) -- Should work via inheritance
      
      eq(RevType.LOCAL, local_rev.type)
      eq("LOCAL", tostring(local_rev))
    end)
  end)

  describe("Integration Scenarios", function()
    it("should handle file vs VCS content comparison", function()
      -- Create a temporary file
      local temp_file = vim.fn.tempname()
      vim.fn.writefile({"file content"}, temp_file)
      
      local file_ref = FileReference(temp_file)
      local vcs_ref = VCSReference(VCSReferenceType.COMMIT, "abc123")
      
      -- Both should be ContentReference instances
      eq(true, file_ref:is_filesystem())
      eq(false, file_ref:is_vcs())
      
      eq(false, vcs_ref:is_filesystem())
      eq(true, vcs_ref:is_vcs())
      
      -- They should not be equal
      eq(false, file_ref:equals(vcs_ref))
      
      vim.fn.delete(temp_file)
    end)

    it("should provide unique content hashes", function()
      local temp_file1 = vim.fn.tempname()
      local temp_file2 = vim.fn.tempname()
      vim.fn.writefile({"content"}, temp_file1)
      vim.fn.writefile({"content"}, temp_file2)
      
      local ref1 = FileReference(temp_file1)
      local ref2 = FileReference(temp_file2)
      
      local hash1 = ref1:content_hash()
      local hash2 = ref2:content_hash()
      
      eq("string", type(hash1))
      eq("string", type(hash2))
      -- Different files should have different hashes (different paths/times)
      neq(hash1, hash2)
      
      vim.fn.delete(temp_file1)
      vim.fn.delete(temp_file2)
    end)
  end)
end)