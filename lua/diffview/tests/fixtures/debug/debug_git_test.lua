-- Debug the exact GitAdapter test that's failing
package.path = "./lua/?.lua;" .. package.path

-- Initialize minimum required globals
_G.DiffviewGlobal =
  { logger = { error = print, warn = print, debug = print, info = print, fmt_debug = print } }

local helpers = require("diffview.tests.helpers")
local GitAdapter = require("diffview.adapters.vcs.adapters.git").GitAdapter
local fixtures = require("diffview.tests.fixtures.git_fixtures")

local eq, neq = helpers.eq, helpers.neq

print("=== Debug GitAdapter verify_rev_arg test ===")

local tmp_dir, old_cwd = fixtures.create_temp_repo()
print("Created temp repo at:", tmp_dir)

-- Run bootstrap first (important!)
GitAdapter.run_bootstrap()

local adapter = GitAdapter({ toplevel = tmp_dir })
print("Created adapter with context:")
print("  toplevel:", adapter.ctx.toplevel)
print("  dir:", adapter.ctx.dir)

-- Test the failing case: invalid revision
print("\n=== Testing invalid revision ===")
local ok, output = adapter:verify_rev_arg("nonexistent-ref")
print("Result - ok:", ok, type(ok))
print("Result - output:", output, type(output))

print("Expected: ok = false (boolean)")
print("Actual: ok =", ok, "(" .. type(ok) .. ")")

print("\n=== Testing valid revision ===")
local ok2, output2 = adapter:verify_rev_arg("HEAD")
print("Result - ok:", ok2, type(ok2))
print("Result - output:", output2, type(output2), output2 and #output2)

fixtures.cleanup_temp_repo(tmp_dir, old_cwd)
print("\n=== Test complete ===")

