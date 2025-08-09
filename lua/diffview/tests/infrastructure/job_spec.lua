local helpers = require("diffview.tests.helpers")
local Job = require("diffview.job").Job

local eq = helpers.eq

describe("Job Execution", function()
  describe("Basic job lifecycle", function()
    it("executes successful commands", function()
      local completed = false
      local job = Job({
        command = "echo",
        args = { "test" },
        log_opt = { silent = true }, -- Prevent logger errors in tests
        on_exit = function() completed = true end,
      })

      job:start()
      vim.wait(1000, function() return completed end)

      eq(0, job.code)
      eq("test", vim.trim(job.stdout[1]))
    end)

    it("handles command failures", function()
      local failed = false
      local job = Job({
        command = "false",
        log_opt = { silent = true }, -- Prevent logger errors in tests
        on_exit = function(job, ok, err) failed = not ok end,
      })

      job:start()
      vim.wait(1000, function() return job:is_done() end)

      eq(true, failed)
      eq(true, job.code ~= 0) -- Verify non-zero exit code
    end)

    it("supports job cancellation", function()
      local job = Job({
        command = "sleep",
        args = { "2" },
        log_opt = { silent = true }, -- Prevent logger errors in tests
      })

      job:start()
      -- Kill the job after a short delay
      vim.wait(100)
      job:kill(15) -- SIGTERM
      vim.wait(500, function() return job:is_done() end)

      eq(true, job:is_done())
    end)
  end)
end)
