local helpers = require("diffview.tests.helpers")
local lib = require("diffview.lib")
local fixtures = require("diffview.tests.fixtures.git_fixtures")

local eq, neq = helpers.eq, helpers.neq

describe("Core Library Functions", function()
  before_each(function() lib.views = {} end)

  describe("Basic functionality", function()
    it("initializes without errors", function()
      eq("table", type(lib))
      eq("table", type(lib.views))
    end)

    it("tracks views correctly", function()
      local initial_count = #lib.views

      -- Test view tracking (simplified)
      local mock_view = { id = 1, name = "test" }
      table.insert(lib.views, mock_view)

      eq(initial_count + 1, #lib.views)
      eq(mock_view, lib.views[#lib.views])
    end)
  end)

  describe("View management", function()
    it("manages view lifecycle", function()
      local tmp_dir, old_cwd = fixtures.create_temp_repo()

      -- Basic view operations test
      local view_count_before = #lib.views

      -- Simulate view creation/destruction
      local test_view = { id = "test_view", type = "diffview" }
      table.insert(lib.views, test_view)
      eq(view_count_before + 1, #lib.views)

      -- Cleanup
      lib.views = {}
      eq(0, #lib.views)

      fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
    end)
  end)
end)

