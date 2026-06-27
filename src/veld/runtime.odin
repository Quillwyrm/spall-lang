package veld

import "core:fmt"
import "core:os"


run_string :: proc(vm: ^VM, source: string) -> bool {
	code, ok := compile_source(source)
	if !ok {
		vm.error_string = Compiler.error_string
		return false
	}

	return run_code(vm, &code)
}

run_file :: proc(vm: ^VM, path: string) -> bool {
	bytes, read_error := os.read_entire_file(path, context.allocator)
	if read_error != nil {
		vm.error_string = fmt.tprintf("could not read file `%s`: %v", path, read_error)
		return false
	}
	defer delete(bytes)

	return run_string(vm, string(bytes))
}
