package kiln

TokenKind :: enum {
	EOF,
	ERROR,

	WORD,
	INT,
	FLOAT,
	//BOOL,
	// STRING,
	// NAME,        // :foo

	// LEFT_BRACE,  // {
	// RIGHT_BRACE, // }

	// LEFT_BRACKET,  // [
	// RIGHT_BRACKET, // ]

	// LEFT_PAREN,  // (
	// RIGHT_PAREN, // )

	// COMMA,      // ,
	// SEMICOLON,  // ;
}

TokenValue :: union {
    i64,
    f64,
    string,
}

Token :: struct {
	kind:  TokenKind,
	value: TokenValue,
	start: int,
}

Lexer := struct {
	source: string,
	//source_name: string,

	index:       int,
	token_start: int,
}{}
