package spall

import "core:strconv"
import "core:fmt"


// Token model ====================================================================================

TokenKind :: enum {
	EOF,
	ERROR,

	WORD,
	INT,
	FLOAT,

	// Later:
	// STRING,
	// NAME, // :foo
	//
	// TRUE,
	// FALSE,
	//
	// LEFT_BRACE,
	// RIGHT_BRACE,
	// LEFT_BRACKET,
	// RIGHT_BRACKET,
	// LEFT_PAREN,
	// RIGHT_PAREN,
	// SEMICOLON,
}

TokenValue :: union {
	i64,
	f64,
	string,
}

// Token stores semantic lexer output and its source-start byte offset.
Token :: struct {
	kind:  TokenKind,
	value: TokenValue,
	start: int,
}


// Lexer state ====================================================================================

// Lexer runs one active scan at a time; it is a package-level singleton.
Lexer := struct {
	source: string,

	index:       int,
	token_start: int,
}{}


// Token emission =================================================================================

// Use make_token so string TokenValue values are built before the Token literal.
// This avoids the dev-2026-03-nightly backend panic from
// Token{ value = TokenValue("string literal") }.
make_token :: proc(kind: TokenKind, value: TokenValue = {}) -> Token {
	return Token {
		kind  = kind,
		value = value,
		start = Lexer.token_start,
	}
}

lexer_error :: proc(message: string) -> Token {
	return make_token(.ERROR, TokenValue(message))
}


// Character classes ==============================================================================

is_digit :: proc(ch: u8) -> bool {
	return ch >= '0' && ch <= '9'
}


// Token scans ====================================================================================

// lex_number consumes a Spall numeric literal and cooks it to INT or FLOAT.
// Negative numeric spellings are literals in Spall; "-" alone is a WORD.
lex_number :: proc() -> Token {
	if Lexer.source[Lexer.index] == '-' {
		Lexer.index += 1
	}

	is_float := false

	if Lexer.source[Lexer.index] == '.' {
		is_float = true
		Lexer.index += 1
	}

	for Lexer.index < len(Lexer.source) && is_digit(Lexer.source[Lexer.index]) {
		Lexer.index += 1
	}

	if Lexer.index < len(Lexer.source) && Lexer.source[Lexer.index] == '.' {
		is_float = true
		Lexer.index += 1

		for Lexer.index < len(Lexer.source) && is_digit(Lexer.source[Lexer.index]) {
			Lexer.index += 1
		}
	}

	// First pass is whitespace-tokenized. If a numeric spelling runs into
	// non-whitespace text, surface it as a malformed number instead of splitting it.
	if Lexer.index < len(Lexer.source) {
		ch := Lexer.source[Lexer.index]
		if ch != ' ' && ch != '\t' && ch != '\r' && ch != '\n' {
			return lexer_error("invalid number literal")
		}
	}

	token_text := Lexer.source[Lexer.token_start:Lexer.index]

	if is_float {
		value, ok := strconv.parse_f64(token_text)
		if !ok {
			return lexer_error("invalid float literal")
		}

		return make_token(.FLOAT, TokenValue(value))
	}

	value, ok := strconv.parse_i64(token_text)
	if !ok {
		return lexer_error("invalid int literal")
	}

	return make_token(.INT, TokenValue(value))
}

lex_word :: proc() -> Token {
	for Lexer.index < len(Lexer.source) {
		ch := Lexer.source[Lexer.index]
		if ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' {
			break
		}
		Lexer.index += 1
	}

	token_text := Lexer.source[Lexer.token_start:Lexer.index]
	return make_token(.WORD, TokenValue(token_text))
}


// Source lexing ==================================================================================

begin_lex :: proc(source: string) {
	Lexer.source = source
	Lexer.index = 0
	Lexer.token_start = 0
}

lex_next_token :: proc() -> Token {
	for Lexer.index < len(Lexer.source) {
		ch := Lexer.source[Lexer.index]
		if ch != ' ' && ch != '\t' && ch != '\r' && ch != '\n' {
			break
		}
		Lexer.index += 1
	}

	Lexer.token_start = Lexer.index

	if Lexer.index >= len(Lexer.source) {
		return make_token(.EOF)
	}

	ch := Lexer.source[Lexer.index]

	if is_digit(ch) {
		return lex_number()
	}

	if ch == '.' && Lexer.index + 1 < len(Lexer.source) && is_digit(Lexer.source[Lexer.index + 1]) {
		return lex_number()
	}

	if ch == '-' && Lexer.index + 1 < len(Lexer.source) && is_digit(Lexer.source[Lexer.index + 1]) {
		return lex_number()
	}

	if ch == '-' &&
	   Lexer.index + 2 < len(Lexer.source) &&
	   Lexer.source[Lexer.index + 1] == '.' &&
	   is_digit(Lexer.source[Lexer.index + 2]) {
		return lex_number()
	}

	return lex_word()
}


// Debug ==========================================================================================

debug_print_tokens :: proc(source: string) {
	begin_lex(source)

	for {
		token := lex_next_token()

		switch token.kind {
		case .EOF:
			fmt.printf("%-6s\n", "EOF")
			return

		case .ERROR:
			message := token.value.(string)
			fmt.printf("%-6s %s\n", "ERROR", message)
			return

		case .WORD:
			text := token.value.(string)
			fmt.printf("%-6s %s\n", "WORD", text)

		case .INT:
			value := token.value.(i64)
			fmt.printf("%-6s %d\n", "INT", value)

		case .FLOAT:
			value := token.value.(f64)
			fmt.printf("%-6s %g\n", "FLOAT", value)
		}
	}
}
