local helpers = require("diffview.tests.helpers")
local Job = require("diffview.job").Job
local MultiJob = require("diffview.multi_job").MultiJob

local eq = helpers.eq

describe("MultiJob Execution", function()
  describe("Parallel job execution", function()
    it("runs multiple jobs concurrently", function()
      local completed = false
      local jobs = {
        Job({ command = "echo", args = { "job1" }, log_opt = { silent = true } }),
        Job({ command = "echo", args = { "job2" }, log_opt = { silent = true } }),
      }
      local multi_job = MultiJob(jobs, {
        log_opt = { silent = true }, -- Prevent logger errors in tests
        on_exit = function() completed = true end,
      })

      multi_job:start()
      vim.wait(1000, function() return multi_job:is_done() end)

      eq(true, completed)
      eq(true, multi_job:is_done())
    end)

    it("handles mixed success/failure", function()
      local jobs = {
        Job({ command = "echo", args = { "success" }, log_opt = { silent = true } }),
        Job({ command = "false", log_opt = { silent = true } }),
      }
      local multi_job = MultiJob(jobs, {
        log_opt = { silent = true }, -- Prevent logger errors in tests
      })

      multi_job:start()
      vim.wait(1000, function() return multi_job:is_done() end)

      eq(true, multi_job:is_done())
      -- Should fail because one job returned non-zero exit code
      local ok, err = multi_job:is_success()
      eq(false, ok)
    end)
  end)
end)
