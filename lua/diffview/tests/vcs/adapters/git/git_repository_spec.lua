local helpers = require("diffview.tests.helpers")
local GitAdapter = require("diffview.adapters.vcs.adapters.git").GitAdapter
local fixtures = require("diffview.tests.fixtures.git_fixtures")

local eq, neq = helpers.eq, helpers.neq

describe("Git Repository Detection", function()
  before_each(function() GitAdapter.run_bootstrap() end)

  describe("GitAdapter.find_toplevel()", function()
    it("detects valid git repository", function()
      local tmp_dir, old_cwd = fixtures.create_temp_repo()

      local err, toplevel = GitAdapter.find_toplevel({ tmp_dir })

      eq(nil, err)
      eq(tmp_dir, toplevel)

      fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)

    it("rejects non-git directory", function()
      local tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")

      local err, toplevel = GitAdapter.find_toplevel({ tmp_dir })

      neq(nil, err)
      eq(true, string.find(err, "not a git repo") ~= nil)

      vim.fn.delete(tmp_dir, "rf")
    end)

    it("finds parent repository", function()
      local tmp_dir, old_cwd = fixtures.create_temp_repo()
      local nested_dir = tmp_dir .. "/nested"
      vim.fn.mkdir(nested_dir, "p")

      local err, toplevel = GitAdapter.find_toplevel({ nested_dir })

      eq(nil, err)
      eq(tmp_dir, toplevel)

      fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)
  end)

  describe("GitAdapter:get_dir()", function()
    it("locates .git directory", function()
      local tmp_dir, old_cwd = fixtures.create_temp_repo()
      local adapter = GitAdapter({ toplevel = tmp_dir })

      local git_dir = adapter:get_dir(tmp_dir)

      neq(nil, git_dir)
      eq(1, vim.fn.isdirectory(git_dir))

      fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)
  end)
end)

