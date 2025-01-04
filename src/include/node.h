#ifndef NODE_H
#define NODE_H
#include <stddef.h>
#include <stdint.h>

typedef enum {
	NODE_TYPE_BINOP = 1,
	NODE_TYPE_VAR,
	NODE_TYPE_VALUE,
	NODE_TYPE_IF,
	NODE_TYPE_WHILE,
	NODE_TYPE_FOR,
	NODE_TYPE_FUNC,
	NODE_TYPE_VARDECL,
	NODE_TYPE_VARDECLS,
	NODE_TYPE_STATEMENT,
	NODE_TYPE_STATEMENTS,
} NodeType;

typedef enum {
	TYPE_INT, // unspecified width (>=64 bit)
	TYPE_STRING,
	TYPE_VOID,
	TYPE_AUTO,
} Type;

typedef struct {
	NodeType type;
	void *data;
} Node;

typedef struct {
	Type typeinfo;
	void *data;
} Value;

typedef struct {
	Node *left;
	Node *right;
	int operator_;
} BinaryOp;

typedef struct {
	Type typeinfo;
	const char *identifier;
} VariableDeclaration;

typedef struct variable_list {
	VariableDeclaration *var_decl;
	struct variable_list *next;
} VariableDeclarations;

typedef struct {
	VariableDeclaration *var_decl;
	Node *init;
} Variable;


typedef struct statements {
	Node *statement;
	struct statements *next;
} Statements;
// fn IDENT ( VariableDeclarations* ) -> TYPE { BLOCK* }
typedef struct {
	Type typeinfo;
	const char *identifier;
	VariableDeclarations *var_decls;
	Statements *statements;
} Function;

Variable *deep_copy_var(Variable *to_copy);
Value *deep_copy_value(Value *to_copy);
BinaryOp *deep_copy_binop(BinaryOp *to_copy);
VariableDeclaration *deep_copy_vardecl(VariableDeclaration *to_copy);
Statements *deep_copy_statements(Statements *to_copy);
Node *deep_copy_node(Node *to_copy);

Node *make_node(NodeType type);
VariableDeclaration *make_vardecl(Type type, const char *identifier);
Variable *make_variable(VariableDeclaration *var_decl, Node *init);
Value *make_value_int(int64_t data);
BinaryOp *make_binop(Node *left, Node *right, int op);
Function *make_function(const char *identifier, VariableDeclarations *var_decls, Type type, Statements *statements);

void print_node_tree(Node *node);
void print_variable(Variable *variable);
Type type_of_node(Node *);
const char *type_to_string(Type type);


void finalize_tree(Node *node);
#endif
