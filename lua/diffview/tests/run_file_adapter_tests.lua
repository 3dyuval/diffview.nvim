#!/usr/bin/env lua

-- Simple test runner for FileAdapter tests
-- This script demonstrates how to run the specific FileAdapter test files

local function run_test_file(test_file)
  print("Running tests from: " .. test_file)
  local success, result = pcall(function()
    -- In the actual test environment, this would use plenary
    -- For now, just verify the file can be loaded
    require(test_file:gsub("lua/", ""):gsub("/", "."):gsub(".lua$", ""))
    return true
  end)

  if success then
    print("✓ " .. test_file .. " loaded successfully")
  else
    print("✗ " .. test_file .. " failed to load: " .. tostring(result))
  end

  return success
end

local fileadapter_tests = {
  "lua/diffview/tests/fixtures/file_fixtures.lua",
  "lua/diffview/tests/src/source_router_spec.lua",
  "lua/diffview/tests/src/adapters/file/file_adapter_spec.lua",
  "lua/diffview/tests/integration/cross_adapter_spec.lua",
}

print("FileAdapter Test Suite")
print("======================")
print()

local all_passed = true

for _, test_file in ipairs(fileadapter_tests) do
  local success = run_test_file(test_file)
  all_passed = all_passed and success
  print()
end

print("Summary")
print("=======")
if all_passed then
  print("✓ All FileAdapter test files loaded successfully")
  print("Ready for implementation!")
else
  print("✗ Some test files have issues")
  print("Fix syntax errors before implementing FileAdapter")
end

-- Instructions for actual test execution
print()
print("To run these tests with Plenary:")
print("================================")
print("make test")
print("-- OR --")
print(
  "nvim --headless -c \"PlenaryBustedDirectory lua/diffview/tests/src { minimal_init = 'scripts/minimal_init.vim' }\""
)
print(
  "nvim --headless -c \"PlenaryBustedDirectory lua/diffview/tests/integration { minimal_init = 'scripts/minimal_init.vim' }\""
)

