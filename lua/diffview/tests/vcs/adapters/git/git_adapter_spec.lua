local helpers = require("diffview.tests.helpers")
local GitAdapter = require("diffview.vcs.adapters.git").GitAdapter
local fixtures = require("diffview.tests.fixtures.git_fixtures")

local eq, neq = helpers.eq, helpers.neq

describe("Git Adapter Core", function()
  before_each(function() GitAdapter.run_bootstrap() end)

  describe("Command execution", function()
    it("executes git commands", function()
      local tmp_dir, old_cwd = fixtures.create_temp_repo()
      local adapter = GitAdapter({ toplevel = tmp_dir })

      local stdout, code, stderr = adapter:exec_sync({ "rev-parse", "--show-toplevel" }, tmp_dir)

      eq(0, code)
      eq(tmp_dir, vim.trim(stdout[1]))

      fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)

    it("handles command failures", function()
      local tmp_dir, old_cwd = fixtures.create_temp_repo()
      local adapter = GitAdapter({ toplevel = tmp_dir })

      local stdout, code, stderr = adapter:exec_sync({ "invalid-command" }, tmp_dir)

      neq(0, code)
      eq(true, #stderr > 0)

      fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)
  end)

  describe("Revision validation", function()
    it("validates existing revisions", function()
      local tmp_dir, old_cwd = fixtures.create_temp_repo()
      local adapter = GitAdapter({ toplevel = tmp_dir })

      local ok, output = adapter:verify_rev_arg("HEAD")

      eq(true, ok)
      eq(1, #output)

      fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)

    it("rejects invalid revisions", function()
      local tmp_dir, old_cwd = fixtures.create_temp_repo()
      local adapter = GitAdapter({ toplevel = tmp_dir })

      local ok, output = adapter:verify_rev_arg("nonexistent-ref")

      eq(false, ok)

      fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)
  end)

  describe("Path utilities", function()
    it("splits pathspecs", function()
      local magic, pattern = GitAdapter.pathspec_split(":!exclude.txt")
      eq(":!", magic)
      eq("exclude.txt", pattern)

      local magic2, pattern2 = GitAdapter.pathspec_split("normal.txt")
      eq("", magic2)
      eq("normal.txt", pattern2)
    end)
  end)
end)

