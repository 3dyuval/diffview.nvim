local helpers = require("diffview.tests.helpers")
local GitAdapter = require("diffview.adapters.vcs.adapters.git").GitAdapter

local eq = helpers.eq

describe("Git Bootstrap", function()
  describe("GitAdapter.run_bootstrap()", function()
    it("detects git availability", function()
      GitAdapter.run_bootstrap()

      eq(true, GitAdapter.bootstrap.done)
      eq(true, GitAdapter.bootstrap.ok)
    end)

    it("validates git version", function()
      GitAdapter.run_bootstrap()

      local version = GitAdapter.bootstrap.version
      eq(true, version.major >= 2)

      if version.major == 2 then eq(true, version.minor >= 31) end
    end)

    it("caches results", function()
      GitAdapter.bootstrap.done = false
      GitAdapter.run_bootstrap()
      local first_result = GitAdapter.bootstrap.ok

      GitAdapter.run_bootstrap()
      eq(first_result, GitAdapter.bootstrap.ok)
    end)
  end)
end)

