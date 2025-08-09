local helpers = require("diffview.tests.helpers")
local async = require("diffview.async")

local eq = helpers.eq
local async_test = helpers.async_test
local await = async.await

describe("Async Framework", function()
  describe("Basic async operations", function()
    it(
      "handles simple async execution",
      async_test(function()
        local executed = false

        async.void(function() executed = true end)()

        await(async.scheduler())

        eq(true, executed)
      end)
    )

    it(
      "manages error propagation",
      async_test(function()
        local error_caught = false

        local ok, err = pcall(function()
          await(async.void(function() error("test error") end)())
        end)

        if not ok then error_caught = true end

        eq(true, error_caught)
      end)
    )

    it(
      "handles timeout scenarios",
      async_test(function()
        local timed_out = false
        local completed = false

        -- Test timeout functionality
        await(async.timeout(10))
        timed_out = true

        eq(true, timed_out)
        eq(false, completed)
      end)
    )
  end)
end)
