package main

import "core:fmt"
import "core:os"
import "spall"


print_help :: proc() {
	fmt.println("spall")
	fmt.println("")
	fmt.println("Usage:")
	fmt.println("  spall run <file>")
	fmt.println("  spall eval <source>")
	fmt.println("  spall dump <source>")
}

join_args :: proc(args: []string, start: int) -> string {
	result := ""

	for index := start; index < len(args); index += 1 {
		if index > start {
			result = fmt.tprintf("%s %s", result, args[index])
		} else {
			result = args[index]
		}
	}

	return result
}

main :: proc() {
	if len(os.args) < 2 {
		print_help()
		return
	}

	command := os.args[1]

	if command == "help" || command == "--help" || command == "-h" {
		print_help()
		return
	}

	if command == "run" {
		if len(os.args) != 3 {
			fmt.eprintln("usage: spall run <file>")
			os.exit(1)
		}

		vm: spall.VM
		if !spall.run_file(&vm, os.args[2]) {
			fmt.eprintln(vm.error_string)
			os.exit(1)
		}

		return
	}

	if command == "eval" {
		if len(os.args) < 3 {
			fmt.eprintln("usage: spall eval <source>")
			os.exit(1)
		}

		source := join_args(os.args, 2)

		vm: spall.VM
		if !spall.run_string(&vm, source) {
			fmt.eprintln(vm.error_string)
			os.exit(1)
		}

		return
	}

	if command == "dump" {
		if len(os.args) < 3 {
			fmt.eprintln("usage: spall dump <source>")
			os.exit(1)
		}

		source := join_args(os.args, 2)

		code, ok := spall.compile_source(source)
		if !ok {
			fmt.eprintln(spall.Compiler.error_string)
			os.exit(1)
		}

		spall.debug_print_code(&code)
		return
	}

	fmt.eprintfln("unknown command: %s", command)
	print_help()
	os.exit(1)
}
