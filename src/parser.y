%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdbool.h>
#include "node.h"
#include "driver.h"

// Declare tokens
#define MAX_VARIABLES 100
Variable* variables[MAX_VARIABLES] = {0};
int var_count = 0;

// Function declarations
int yylex(void);
void yyerror(FILE *fp, const char *s, ...);
void yyerror_verbose(FILE *fp, const char *s, size_t lineno, size_t first_column, size_t last_column, ...);
static Variable *lookup_variable(const char *s, FILE *fp);
static bool variable_reassign(const char *s, Node *expr, FILE *fp);
extern Node *AST;

%}
%locations
%parse-param {FILE *fp}
%define parse.error custom
%union {
	long num;
	char *str;
	Node *node;
	Type type;
}

%type <node> Expression ForLoop WhileLoop FunctionDeclaration FunctionArguments
%type <node> StatementBlock Statement Statements LetIdentifierType PrintFunction
%type <node> Primary Term Factor Unary
%type <type> Type
%token <str> IDENTIFIER
%token <num> NUMBER
%token <str> STRING
%token INT_TYPE "int" STRING_TYPE "string" VOID_TYPE "void"
%token LET "let" MUT "mut" WHILE "while" FOR "for" PRINT "__print" FN "fn" THIN_ARROW "->"
%left POWER "^^"
%left LOGICAL_OR "||"
%left LOGICAL_AND "&&"
%left OR "|"
%left XOR "^"
%left AND "&"
%left LSHIFT "<<" RSHIFT ">>"
%left ADD "+" SUB "-"
%left MUL "*" DIV "/" MOD "%"
%%

// Grammar rules

Program
		: Statements {
			print_node_tree($1);
			finalize_tree($1);
		}
		| Empty
		;
Statements
	: Statement Statements {
		Node *n = make_node(NODE_TYPE_STATEMENTS);
		Statements *statements = malloc(sizeof(*statements));
		statements->statement = $1;
		statements->next = $2->data;
		free($2);
		n->data = statements;
		$$ = n;
	}
	| Statement {
		Node *n = make_node(NODE_TYPE_STATEMENTS);
		Statements *statements = malloc(sizeof(*statements));
		statements->next = NULL;
		statements->statement = $1;
		n->data = statements;
		$$ = n;
	}
	| StatementBlock
	;


Expression
		: Term
    | Expression ADD Term {
			Node *n = make_node(NODE_TYPE_BINOP);
			n->data = make_binop($1, $3, ADD);
			$$ = n;
		}
    | Expression SUB Term {
			Node *n = make_node(NODE_TYPE_BINOP);
			n->data = make_binop($1, $3, SUB);
			$$ = n;
		}
    ;

Term
		: Factor
    | Term MUL Factor {
			Node *n = make_node(NODE_TYPE_BINOP);
			n->data = make_binop($1, $3, MUL);
			$$ = n;

		}
    | Term DIV Factor {
			if ($3 != 0) {
				Node *n = make_node(NODE_TYPE_BINOP);
				n->data = make_binop($1, $3, DIV);
				$$ = n;
			} else {
				yyerror(fp, "Attempted division by zero");
			}
		}
    ;

Factor
		: Unary
    | Factor RSHIFT Primary {
				Node *n = make_node(NODE_TYPE_BINOP);
				n->data = make_binop($1, $3, RSHIFT);
				$$ = n;
			}
    | Factor LSHIFT Primary {
				Node *n = make_node(NODE_TYPE_BINOP);
				n->data = make_binop($1, $3, LSHIFT);
				$$ = n;
			}
    | Factor AND Primary {
				Node *n = make_node(NODE_TYPE_BINOP);
				n->data = make_binop($1, $3, AND);
				$$ = n;
			}
    | Factor XOR Primary {
				Node *n = make_node(NODE_TYPE_BINOP);
				n->data = make_binop($1, $3, XOR);
				$$ = n;
			}
    | Factor OR Primary {
				Node *n = make_node(NODE_TYPE_BINOP);
				n->data = make_binop($1, $3, OR);
				$$ = n;
			}
    | Factor LOGICAL_OR Primary {
				Node *n = make_node(NODE_TYPE_BINOP);
				n->data = make_binop($1, $3, LOGICAL_OR);
				$$ = n;
			}
    ;

Unary
	: Primary
  | Unary POWER Primary {
			Node *n = make_node(NODE_TYPE_BINOP);
			n->data = make_binop($1, $3, POWER);
			$$ = n;
		}
	;
Primary
		: IDENTIFIER {
			Node *n = make_node(NODE_TYPE_VAR);
			n->data = lookup_variable($1, fp);
			if (n->data == NULL)
				yyerror(fp, "variable %s not found\n", $1);

			free($1);
			$$ = n;
			}
    | NUMBER {
			Node *n = make_node(NODE_TYPE_VALUE);

			Value *v = make_value_int($1);

			n->data = v;
			$$ = n;
		}
		| STRING {
			Node *n = make_node(NODE_TYPE_VALUE);

			Value *v = malloc(sizeof(*v));
			v->data = (void *)$1;
			v->typeinfo = TYPE_STRING;

			n->data = v;
			$$ = n;
		}
    | '(' Expression ')' { $$ = $2; }
    ;

Let
		: LET
		// a 'let mut' variable cannot have an expression that is immutable.
		| LET MUT
		;

LetIdentifierType
		: Let IDENTIFIER {
			VariableDeclaration *var_decl = make_vardecl(TYPE_AUTO, $2);
			Node *n = make_node(NODE_TYPE_VARDECL);
			n->data = var_decl;
			$$ = n;
		}
		| Let IDENTIFIER ':' Type {
			VariableDeclaration *var_decl = make_vardecl($4, $2);
			Node *n = make_node(NODE_TYPE_VARDECL);
			n->data = var_decl;
			$$ = n;
		}
		;
Type
		: INT_TYPE { $$ = TYPE_INT; }
		| STRING_TYPE { $$ = TYPE_STRING; }
		| VOID_TYPE { $$ = TYPE_VOID; }
		;
Statement /* let <ID> <: Type>* = <expr>; */
		: LetIdentifierType '=' Expression ';' {
				// Store variable name and value
				Type let_type = ((VariableDeclaration *)$1->data)->typeinfo;
				if (var_count < MAX_VARIABLES) {
					if (let_type == TYPE_AUTO) {
						let_type = type_of_node($3);
						((VariableDeclaration *)$1->data)->typeinfo = let_type;
					}
					if (type_of_node($3) != let_type) {
						yyerror_verbose(fp, "type of variable does not match expression type (%s vs %s)", @1.first_line, @1.first_column, @3.last_column, type_to_string(let_type), type_to_string(type_of_node($3)));
					}
					Variable *errvar;
					if (( errvar = lookup_variable(((VariableDeclaration *)$1->data)->identifier, fp)) != NULL) {
						Node *tmpnode = make_node(NODE_TYPE_VAR);
						tmpnode->data = errvar;
						finalize_tree(tmpnode);
						yyerror_verbose(fp, "Variable redeclaration of `%s'", @1.first_line, @1.first_column, @1.last_column, ((VariableDeclaration *)$1->data)->identifier);
					}

					Variable *var = make_variable($1->data, $3);
					// LetIdentifierType is unboxed and we abandon the box here
					free($1);

					variables[var_count] = var;				// Save variable value
					var_count++;
					Node *n = make_node(NODE_TYPE_VAR);
					n->data = var;
					$$ = n;
				} else {
						yyerror(fp, "Too many variables declared.");
				}
		}
		| IDENTIFIER '=' Expression ';' {
			bool reassigned = variable_reassign($1, $3, fp);
			if (!reassigned) {
				yyerror_verbose(fp, "Variable %s not found when trying to assign", @1.first_line, @1.first_column, @1.last_column, $1);
			}
			Variable *var = lookup_variable($1, fp);
			Node *n = make_node(NODE_TYPE_VAR);
			n->data = var;
			$$ = n;
		}
		| WhileLoop { $$ = $1; }
		| ForLoop { $$ = $1; }
		| FunctionDeclaration { $$ = $1; }
		| PrintFunction { $$ = $1; }
		;

StatementBlock
		: '{' Statements '}' { $$ = $2; }
		| '{' /* empty */ '}' {
		  // an empty block has value '()', which is of type void.
			Node *n = make_node(NODE_TYPE_STATEMENTS);
			Statements *statements = malloc(sizeof(*statements));
			// only one statement
			statements->next = NULL;

			Node *n_val = make_node(NODE_TYPE_VALUE);

			// data being NULL and typeinfo being TYPE_VOID signifies '()'
			Value *value = malloc(sizeof(*value));
			value->typeinfo = TYPE_VOID;
			value->data = NULL;

			n_val->data = value;
			statements->statement = n_val;
			n->data = statements;
			$$ = n;
		}
		;

Empty
		: ;

FunctionArguments
		: IDENTIFIER ':' Type ',' FunctionArguments {
			Node *n = make_node(NODE_TYPE_VARDECLS);
			VariableDeclarations *var_decls = malloc(sizeof(*var_decls));
			var_decls->var_decl = make_vardecl($3, $1);
			var_decls->next = $5->data;
			free($5);
			n->data = var_decls;
			$$ = n;

		}
		| IDENTIFIER ':' Type {
			Node *n = make_node(NODE_TYPE_VARDECLS);
			VariableDeclarations *var_decls = malloc(sizeof(*var_decls));
			VariableDeclaration *var_decl = make_vardecl($3, $1);

			var_decls->var_decl = var_decl;
			var_decls->next = NULL;
			n->data = var_decls;
			$$ = n;
		}
		| Empty {
			// empty arguments is just NULL everywhere.
			Node *n = make_node(NODE_TYPE_VARDECLS);
			VariableDeclarations *var_decls = malloc(sizeof(*var_decls));
			var_decls->var_decl = NULL;
			var_decls->next = NULL;
			n->data = var_decls;
			$$ = n;
		}
		;

FunctionDeclaration
		: FN IDENTIFIER '(' FunctionArguments ')' THIN_ARROW Type StatementBlock {
			Node *n = make_node(NODE_TYPE_FUNC);
			n->data = make_function($2, $4->data, $7, $8->data);
			free($4);
			free($8);
			$$ = n;
		}
		;

PrintFunction
		: PRINT '(' STRING ')' ';' {
			Node *n = make_node(NODE_TYPE_VALUE);
			Value *v = malloc(sizeof(*v));
			v->typeinfo = TYPE_STRING;
			v->data = $3;
			n->data = v;
			// TODO handle escapes
			printf("%s", $3);
			$$ = n;
		}
		| PRINT '(' IDENTIFIER ')' ';' {
			Node *n = make_node(NODE_TYPE_VALUE);
			Value *v = malloc(sizeof(*v));
			v->typeinfo = TYPE_STRING;
			v->data = $3;
			n->data = v;
			$$ = n;
		}
		;

WhileLoop
		: WHILE Expression StatementBlock
		;

ForLoop
		: FOR '(' Expression ';' Expression ';' Expression ')' StatementBlock
		;


%%

void yyerror(FILE *fp, const char *s, ...) {
	fprintf(stderr, "\033[1;31mError\033[0m ");
	va_list listp;
	va_start(listp, s);
	vfprintf(stderr, s, listp);
	va_end(listp);
	fprintf(stderr, "\n");
	exit(1);
}
// Error handling
void yyerror_verbose(FILE *fp, const char *s, size_t lineno, size_t first_column, size_t last_column, ...) {
		fprintf(stderr, "\033[1;31mError:%zu:%zu-%zu:\033[0m ", lineno, first_column, last_column);
		va_list listp;
		va_start(listp, last_column);
		vfprintf(stderr, s, listp);
		va_end(listp);
		fprintf(stderr, "\n");
		// doesn't end in \n because fgets() contains \n
		fprintf(stderr, " %4zu | %s", lineno, make_line_string_from_file(lineno));
		fprintf(stderr, "      | ");
		for (int i = 0; i < first_column-1; i++) {
			fprintf(stderr, " ");
		}
		fprintf(stderr, "\033[1;31m^");
		for (size_t i = first_column; i < last_column-1; i++) {
			fprintf(stderr, "~");
		}
		fprintf(stderr, "\033[0m\n");

		exit(1);
}
Variable *lookup_variable(const char *s, FILE *fp)
{
	for (int i = 0; i < MAX_VARIABLES; i++) {
		if (variables[i] != NULL && variables[i]->var_decl != NULL &&
			variables[i]->var_decl->identifier != NULL &&
			strcmp(s, variables[i]->var_decl->identifier) == 0) {
			return deep_copy_var(variables[i]);
		}
	}
	return NULL;
}
bool variable_reassign(const char *s, Node *expr, FILE *fp)
{
	for (int i = 0; i < MAX_VARIABLES; i++) {
		if (variables[i] != NULL && variables[i]->var_decl != NULL &&
			variables[i]->var_decl->identifier != NULL &&
			strcmp(s, variables[i]->var_decl->identifier) == 0) {
			variables[i]->init = expr;
			return true;
		}
	}
	return false;
}
int
yyreport_syntax_error(const yypcontext_t *ctx, FILE *fp)
{
  int res = 0;
  YYLOCATION_PRINT(stderr, yypcontext_location(ctx));
  fprintf(stderr, ": syntax error");
  // Report the tokens expected at this point.
  enum { TOKENMAX = 5 };
  yysymbol_kind_t expected[TOKENMAX];
  int n = yypcontext_expected_tokens(ctx, expected, TOKENMAX);
  if (n < 0) {
    // Forward errors to yyparse.
    res = n;
  } else {
    for (int i = 0; i < n; ++i) {
      fprintf(stderr, "%s %s",
               i == 0 ? ": expected" : " or", yysymbol_name(expected[i]));
		}
	}
  // Report the unexpected token.
  yysymbol_kind_t lookahead = yypcontext_token(ctx);
  if (lookahead != YYSYMBOL_YYEMPTY) {
    fprintf(stderr, " before %s", yysymbol_name(lookahead));
	}
  fprintf(stderr, "\n");

  return res;
}
