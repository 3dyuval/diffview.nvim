local helpers = require("diffview.tests.helpers")
local GitAdapter = require("diffview.vcs.adapters.git").GitAdapter
local fixtures = require("diffview.tests.fixtures.git_fixtures")

local eq, neq = helpers.eq, helpers.neq
local async_test = helpers.async_test

describe("Git Async Operations", function()
  before_each(function() GitAdapter.run_bootstrap() end)

  describe("File content retrieval", function()
    it(
      "retrieves file content",
      async_test(function()
        local tmp_dir, old_cwd = fixtures.create_temp_repo()
        local adapter = GitAdapter({ toplevel = tmp_dir })
        local Rev = require("diffview.vcs.adapters.git.rev").GitRev

        local head_rev = Rev("HEAD", "commit")
        local content_received = false
        local file_content

        adapter:show("test1.txt", head_rev, function(stderr, stdout)
          content_received = true
          if not stderr then file_content = stdout end
        end)

        vim.wait(1000, function() return content_received end)

        eq(true, content_received)
        neq(nil, file_content)

        fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
      end)
    )

    it(
      "handles missing files",
      async_test(function()
        local tmp_dir, old_cwd = fixtures.create_temp_repo()
        local adapter = GitAdapter({ toplevel = tmp_dir })
        local Rev = require("diffview.vcs.adapters.git.rev").GitRev

        local head_rev = Rev("HEAD", "commit")
        local error_received = false

        adapter:show("nonexistent.txt", head_rev, function(stderr, stdout)
          if stderr then error_received = true end
        end)

        vim.wait(1000, function() return error_received end)

        eq(true, error_received)

        fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
      end)
    )
  end)
end)

