%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "node.h"
#include "parser.h"

%}
digit [0-9]
identifier [a-zA-Z_][a-zA-Z0-9_]*
multiline_comment \/\*(.|\n|\r|\t)*\*\/
comment \/\/.*
string \"([^"\\]*(\\.[^"\\]*)*)\"

%%

"mut"   { return MUT; }
"let"   { return LET; }
"while" { return WHILE; }
"for" { return FOR; }
"__print" { return PRINT; }
"->" { return THIN_ARROW; }
"fn" { return FN; }
"int" { return INT_TYPE; }
"str" { return STRING_TYPE; }
"void" { return VOID_TYPE; }
{string} {
	size_t len = strlen(yytext);
	char *buf = malloc(strlen(yytext)+1);
	sprintf(buf, "%.*s", (int)(len - 2), yytext+1);
	yylval.str = buf;
	return STRING;
}
{identifier}  {
    yylval.str = strdup(yytext);
    return IDENTIFIER;
}

{digit}+      {
    yylval.num = atoi(yytext);
    return NUMBER;
}
{multiline_comment} {/* eat */}
{comment} {/* eat */}

"="         { return '='; }

";"         { return ';'; }
":" 				{ return ':'; }

[ \t\n]+    { /* ignore whitespace */ }
"(" { return '('; }
")" { return ')'; }
"{" { return '{'; }
"}" { return '}'; }
"+" { return ADD; }
"-" { return SUB; }
"*" { return MUL; }
"/" { return DIV; }
">>" { return RSHIFT; }
"<<" { return LSHIFT; }
"%" { return MOD; }
"^" { return XOR; }
"|" { return OR; }
"&" { return OR; }
"||" { return LOGICAL_OR; }
"&&" { return LOGICAL_AND; }
"^^" { return POWER; }
. {
    printf("Unrecognized character: %s\n", yytext);
    return yytext[0];
}

%%
