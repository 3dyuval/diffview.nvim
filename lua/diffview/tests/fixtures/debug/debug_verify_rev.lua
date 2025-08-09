-- Debug verify_rev_arg logic
local function test_verify_logic()
  -- Simulate failed git command
  local out = nil -- What happens when git command fails completely
  local code = 128 -- git error code

  print("Test 1: out=nil, code=128")
  local result = code == 0 and (out[2] ~= nil or out[1] and out[1] ~= "")
  print("Result:", result, type(result))

  -- Test 2: Empty output
  out = {}
  code = 1
  print("\nTest 2: out={}, code=1")
  result = code == 0 and (out[2] ~= nil or out[1] and out[1] ~= "")
  print("Result:", result, type(result))

  -- Test 3: Valid output
  out = { "abc123" }
  code = 0
  print("\nTest 3: out={'abc123'}, code=0")
  result = code == 0 and (out[2] ~= nil or out[1] and out[1] ~= "")
  print("Result:", result, type(result))

  -- Test 4: Empty string output
  out = { "" }
  code = 0
  print("\nTest 4: out={''}, code=0")
  result = code == 0 and (out[2] ~= nil or out[1] and out[1] ~= "")
  print("Result:", result, type(result))
end

test_verify_logic()

