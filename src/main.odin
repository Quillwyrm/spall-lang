package main

import "core:fmt"
import "core:os"
import "veld"


print_help :: proc() {
	fmt.println("veld")
	fmt.println("")
	fmt.println("Usage:")
	fmt.println("  veld run <file>")
	fmt.println("  veld eval <source>")
	fmt.println("  veld dump <source>")
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
			fmt.eprintln("usage: veld run <file>")
			os.exit(1)
		}

		vm: veld.VM
		if !veld.run_file(&vm, os.args[2]) {
			fmt.eprintln(vm.error_string)
			os.exit(1)
		}

		return
	}

	if command == "eval" {
		if len(os.args) != 3 {
			fmt.eprintln("usage: veld eval <source>")
			os.exit(1)
		}

		vm: veld.VM
		if !veld.run_string(&vm, os.args[2]) {
			fmt.eprintln(vm.error_string)
			os.exit(1)
		}

		return
	}

	if command == "dump" {
		if len(os.args) != 3 {
			fmt.eprintln("usage: veld dump <source>")
			os.exit(1)
		}

		code, ok := veld.compile_source(os.args[2])
		if !ok {
			fmt.eprintln(veld.Compiler.error_string)
			os.exit(1)
		}

		veld.debug_print_code(&code)
		return
	}

	fmt.eprintfln("unknown command: %s", command)
	print_help()
	os.exit(1)
}
