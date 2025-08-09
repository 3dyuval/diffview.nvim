local arg_parser = require("diffview.arg_parser")

print("Testing arg parser...")

print("\nTesting -C path (separate args):")
local args = arg_parser.parse({ "-C", "/tmp/test", "HEAD" }, {})
print("Flags:", vim.inspect(args.flags))
print("Args:", vim.inspect(args.args))
print("get_flag C:", args:get_flag("C"))

print("\nTesting -C=path (equals form):")
local args3 = arg_parser.parse({ "-C=/tmp/test", "HEAD" }, {})
print("Flags:", vim.inspect(args3.flags))
print("Args:", vim.inspect(args3.args))
print("get_flag C:", args3:get_flag("C"))

print("\nTesting revision parsing...")
local args2 = arg_parser.parse({ "HEAD~1", "HEAD" }, {})
print("Type:", type(args2))
print("Args:", vim.inspect(args2.args))
print("Flags:", vim.inspect(args2.flags))
print("First arg:", args2.args[1])
