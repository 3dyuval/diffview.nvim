local helpers = require("diffview.tests.helpers")
local vcs = require("diffview.vcs")
local fixtures = require("diffview.tests.fixtures.git_fixtures")

local eq, neq = helpers.eq, helpers.neq

describe("VCS Adapter Factory", function()
  describe("Adapter discovery", function()
    it("finds git adapter for git repository", function()
      local tmp_dir, old_cwd = fixtures.create_temp_repo()

      local cmd_ctx = {
        toplevel = tmp_dir,
        path_args = { tmp_dir },
      }

      local err, adapter = vcs.get_adapter(cmd_ctx)

      eq(nil, err)
      neq(nil, adapter)
      eq("GitAdapter", adapter.name)

      fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)

    it("returns error for non-VCS directory", function()
      local tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")

      local cmd_ctx = {
        toplevel = tmp_dir,
        path_args = { tmp_dir },
      }

      local err, adapter = vcs.get_adapter(cmd_ctx)

      neq(nil, err)
      eq(nil, adapter)

      vim.fn.delete(tmp_dir, "rf")
    end)
  end)

  describe("Adapter ordering", function()
    it("tries adapters in correct sequence", function()
      -- This tests that the adapter discovery follows the expected order
      local adapters_available = vcs.get_all_adapters()

      eq("table", type(adapters_available))
      eq(true, #adapters_available > 0)

      -- Git should be first in the list
      eq("GitAdapter", adapters_available[1].name)
    end)
  end)
end)

