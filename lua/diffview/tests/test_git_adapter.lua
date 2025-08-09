-- Simple test for git adapter verify_rev_arg
package.path = "./lua/?.lua;" .. package.path

-- Initialize DiffviewGlobal
_G.DiffviewGlobal = { logger = { error = print, warn = print, debug = print, info = print } }

local GitAdapter = require("diffview.adapters.vcs.adapters.git").GitAdapter
local fixtures = require("diffview.tests.fixtures.git_fixtures")

print("Testing GitAdapter verify_rev_arg...")

-- Run bootstrap first
GitAdapter.run_bootstrap()

local tmp_dir, old_cwd = fixtures.create_temp_repo()
local adapter = GitAdapter({ toplevel = tmp_dir })

-- Test valid revision
local ok, output = adapter:verify_rev_arg("HEAD")
print("Valid revision (HEAD):", ok, output and #output or "nil")

-- Test invalid revision
local ok2, output2 = adapter:verify_rev_arg("nonexistent-ref")
print("Invalid revision:", ok2, output2 and #output2 or "nil")

fixtures.cleanup_temp_repo(tmp_dir, old_cwd)

print("Done!")

