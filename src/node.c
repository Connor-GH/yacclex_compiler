#include <math.h>
#include <stdarg.h>
#include <stdint.h>
#include "node.h"
#include <stdio.h>
#include "parser.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <assert.h>


static const int DEBUG_CONSTFOLD = 0;

__attribute__((const)) static inline uint64_t
operator_hash(const char *const s) {
  uint64_t hash = 0;
  const size_t len = strnlen(s, 3);

  for (size_t i = 0; i < len; i++) {
    hash = (hash * 256) + (uint8_t)s[i];
  }
  return hash;
}

int to_operator(const char *const op) {
  const uint64_t hash = operator_hash(op);
  if (hash == operator_hash("+")) {
    return ADD;
  } else if (hash == operator_hash("-")) {
    return SUB;
  } else if (hash == operator_hash("*")) {
    return MUL;
  } else if (hash == operator_hash("/")) {
    return DIV;
  } else if (hash == operator_hash("%")) {
    return MOD;
  } else if (hash == operator_hash(">>")) {
    return RSHIFT;
  } else if (hash == operator_hash("<<")) {
    return LSHIFT;
  } else if (hash == operator_hash("&&")) {
    return LOGICAL_AND;
  } else if (hash == operator_hash("||")) {
    return LOGICAL_OR;
  } else if (hash == operator_hash("|")) {
    return OR;
  } else if (hash == operator_hash("&")) {
    return AND;
  } else if (hash == operator_hash("^")) {
    return XOR;
  } else if (hash == operator_hash("^^")) {
		return POWER;
	}
  return YYerror;
}

const char *operator_to_string(int operator) {
	switch (operator) {
	case ADD: return "+";
	case SUB: return "-";
	case MUL: return "*";
	case DIV: return "/";
	case MOD: return "%";
	case RSHIFT: return ">>";
	case LSHIFT: return "<<";
	case LOGICAL_AND: return "&&";
	case LOGICAL_OR: return "||";
	case OR: return "|";
	case AND: return "&";
	case XOR: return "^";
	case POWER: return "^^";
	case YYerror: return "<ERROR>";
	default: return "<UNKNOWN>";
	}
}

static void *xmalloc(size_t size) {
	void *ptr = malloc(size);
	if (!ptr) {
		perror("malloc");
		exit(EXIT_FAILURE);
	}
	return ptr;
}
// make new node
// caller passes in allocated left and right nodes
//
// returns allocated newnode with allocated string
BinaryOp *make_binop(Node *left, Node *right, int op) {
  BinaryOp *newnode = xmalloc(sizeof(*newnode));
	newnode->left = left;
  newnode->right = right;
  newnode->operator_ = op;
  return newnode;
}

Node *make_node(NodeType type) {
	Node *node = xmalloc(sizeof(*node));
	node->type = type;
	return node;
}

VariableDeclaration *make_vardecl(Type type, const char *identifier) {
	VariableDeclaration *var_decl = xmalloc(sizeof(*var_decl));
	var_decl->typeinfo = type;
	var_decl->identifier = identifier;
	return var_decl;
}

Variable *make_variable(VariableDeclaration *var_decl, Node *init) {
	Variable *variable = xmalloc(sizeof(*variable));
	variable->var_decl = var_decl;
	variable->init = init;
	return variable;
}

Value *make_value_int(int64_t data) {
	Value *value = xmalloc(sizeof(*value));
	value->typeinfo = TYPE_INT;
	value->data = (void *)data;
	return value;
}

Function *make_function(const char *identifier, VariableDeclarations *var_decls, Type type, Statements *statements) {
	Function *func = xmalloc(sizeof(*func));
	func->typeinfo = type;
	func->var_decls = var_decls;
	func->identifier = identifier;
	return func;
}
Variable *deep_copy_var(Variable *to_copy) {
	Variable *to_return = make_variable(deep_copy_vardecl(to_copy->var_decl),
																		 deep_copy_node(to_copy->init));
	return to_return;
}

Value *deep_copy_value(Value *to_copy) {
	Value *val = xmalloc(sizeof(*val));
	val->typeinfo = to_copy->typeinfo;
	if (to_copy->typeinfo == TYPE_STRING && to_copy->data != NULL) {
		val->data = strdup((const char *)to_copy->data);
	} else {
		val->data = to_copy->data;
	}
	return val;
}

BinaryOp *deep_copy_binop(BinaryOp *to_copy) {
	BinaryOp *binop = make_binop(deep_copy_node(to_copy->left), deep_copy_node(to_copy->right), to_copy->operator_);
	return binop;
}

VariableDeclaration *deep_copy_vardecl(VariableDeclaration *to_copy) {
	VariableDeclaration *vardecl = make_vardecl(to_copy->typeinfo, strdup(to_copy->identifier));
	return vardecl;
}

Statements *deep_copy_statements(Statements *to_copy) {
	Statements *statements = NULL;
	Statements *previous = NULL;
	while (statements != NULL) {
		Statements *temp = xmalloc(sizeof(*statements));
		temp->statement = deep_copy_node(to_copy->statement);
		temp->next = NULL;

		if (statements == NULL) {
			statements = temp;
		} else {
			previous->next = temp;
		}
		previous = statements;
		to_copy = to_copy->next;
	}
	return statements;
}

Node *deep_copy_node(Node *to_copy) {
	Node *to_return = make_node(to_copy->type);
	switch (to_return->type) {
	case NODE_TYPE_IF: break;
	case NODE_TYPE_VAR: {
		to_return->data = deep_copy_var(to_copy->data);
		break;
	}
	case NODE_TYPE_FOR: break;
	case NODE_TYPE_FUNC: break;
	case NODE_TYPE_VALUE: {
		to_return->data = deep_copy_value(to_copy->data);
		break;
	}
	case NODE_TYPE_BINOP: {
		to_return->data = deep_copy_binop(to_copy->data);
		break;
	}
	case NODE_TYPE_WHILE: break;
	case NODE_TYPE_VARDECL: {
		to_return->data = deep_copy_vardecl(to_copy->data);
		break;
	}
	case NODE_TYPE_VARDECLS: break;
	case NODE_TYPE_STATEMENTS: {
		to_return->data = deep_copy_statements(to_copy->data);
		break;
	}
	default: to_return->data = NULL;
	}
	return to_return;
}

const char *type_to_string(Type type) {
  switch (type) {
  case TYPE_INT:
    return "int";
  case TYPE_STRING:
    return "string";
  default:
    return "unknown";
  }
}

static int64_t
eval_from_operator(int64_t lhs, int64_t rhs, int operator)
{
	switch (operator) {
	case ADD: return lhs + rhs;
	case SUB: return lhs - rhs;
	case MUL: return lhs * rhs;
	case DIV: return lhs / rhs;
	case MOD: return lhs % rhs;
	case RSHIFT: return lhs >> rhs;
	case LSHIFT: return lhs << rhs;
	case LOGICAL_AND: return lhs && rhs;
	case LOGICAL_OR: return lhs || rhs;
	case OR: return lhs | rhs;
	case AND: return lhs & rhs;
	case XOR: return lhs ^ rhs;
	case POWER: return pow(lhs, rhs);
	case YYerror:
	default:
		assert(0 && "eval_from_operator: unknown operator");
	}
}

/*
 * constant folding:
 * n = node, b = binOp, i = int
 *     n       ->    b   -> i
 *    /  \          /  \
 *   b     b       i    i
 *  /  \ /  \
 * i   i i   i
 */

int64_t constfold(Node *root) {
	if (root->type == NODE_TYPE_VAR) {
		Variable *var = root->data;
		return constfold(var->init);
	}
	if (root->type == NODE_TYPE_VALUE) {
		Value *value = root->data;
		return (int64_t)value->data;
	}
	assert(root->type == NODE_TYPE_BINOP);
	BinaryOp *binop = root->data;
	if (binop->left->type == NODE_TYPE_VALUE) {
		Value *left = binop->left->data;
		assert(left->typeinfo == TYPE_INT);
		if (binop->right->type == NODE_TYPE_VALUE) {
			Value *right = binop->right->data;
			assert(right->typeinfo == TYPE_INT);
			return eval_from_operator((int64_t)left->data, (int64_t)right->data, binop->operator_);
		} else {
			return eval_from_operator((int64_t)left->data, constfold(binop->right), binop->operator_);
		}
	} else {
		Value *right = binop->right->data;
		assert(right->typeinfo == TYPE_INT);
			return eval_from_operator(constfold(binop->left), (int64_t)right->data, binop->operator_);
	}
}

Type type_of_node(Node *node) {
	if (node->type == NODE_TYPE_BINOP) {
		BinaryOp *binop = node->data;
		if (type_of_node(binop->left) == type_of_node(binop->right)) {
			return type_of_node(binop->left);
		} else {
			fprintf(stderr, "type_of_node: lhs type different from rhs type\n");
			fprintf(stderr, "left: %d right %d\n", binop->left->type, binop->left->type);
			exit(1);
		}
	} else if (node->type == NODE_TYPE_VALUE) {
		Value *value = node->data;
		return value->typeinfo;
	} else if (node->type == NODE_TYPE_VAR) {
		Variable *variable = node->data;
		return variable->var_decl->typeinfo;
	} else {
		fprintf(stderr, "Cannot determine type from rhs\n");
		exit(1);
	}
}


void print_variable(Variable *variable) {
	if (variable->var_decl->typeinfo == TYPE_INT)
		printf("%s: %s = %ld\n", variable->var_decl->identifier,
				type_to_string(variable->var_decl->typeinfo), constfold(variable->init));
	else if (variable->var_decl->typeinfo == TYPE_STRING)
		printf("%s: %s = \"%s\"\n", variable->var_decl->identifier,
				type_to_string(variable->var_decl->typeinfo), (char *)variable->init->data);
	else
		printf("%s: %s = <ERROR>\n", variable->var_decl->identifier,
				type_to_string(variable->var_decl->typeinfo));
}

static void print_walk(Node *node, const char *prefix) {
  if (node == NULL) {
    return;
  }
	char *next_prefix = xmalloc(strlen(prefix) + 2 + 1 + 2);
	const char *arrow = "|-";
	const char *segment = "| ";
	const char *end_segment = "  ";
	const char *end_arrow = "`-";

	switch (node->type) {
  case NODE_TYPE_BINOP: {
    BinaryOp *binop = (BinaryOp *)node->data;
    if (binop != NULL) {
      printf("%s%s\033[1;32mBinaryOp\033[0m:\n", prefix, end_arrow);
      printf("%s  %s\033[1;1mOperator\033[0m: %s\n", prefix, arrow, operator_to_string(binop->operator_));
      printf("%s  %s\033[1;36mLeft\033[0m:\n", prefix, arrow);
			sprintf(next_prefix, "%s  %s", prefix, segment);
      print_walk(binop->left, next_prefix);
      printf("%s  %s\033[1;36mRight\033[0m:\n", prefix, end_arrow);
			sprintf(next_prefix, "%s  %s", prefix, end_segment);
      print_walk(binop->right, next_prefix);
    }
    break;
  }
	case NODE_TYPE_VALUE: {
		Value *value = (Value *)node->data;
		if (value != NULL) {
			printf("%s%s\033[1;33mValue\033[0m: ", prefix, end_arrow);
			if (value->typeinfo == TYPE_INT) {
				printf("%lu\n", (unsigned long)value->data);
			} else if (value->typeinfo == TYPE_STRING) {
				printf("\"%s\"\n", (char *)value->data);
			} else {
				printf("unknown\n");
			}
		}
		break;
	}
  case NODE_TYPE_VAR: {
    Variable *var = (Variable *)node->data;
    if (var != NULL) {
      printf("%s%sVariable: \n", prefix, arrow);
			printf("%s  %s\033[1;35mtypeinfo\033[0m: %s\n", prefix, arrow,
								type_to_string(var->var_decl->typeinfo));
			printf("%s  %s\033[1;34midentifier\033[0m: %s\n", prefix, arrow, var->var_decl->identifier);
			printf("%s  %s\033[1;38;5;115minit\033[0m:\n", prefix, end_arrow);
			sprintf(next_prefix, "%s  %s", prefix, end_segment);
			print_walk(var->init, next_prefix);
			if (var->var_decl->typeinfo == TYPE_INT && DEBUG_CONSTFOLD == 1)
				printf("constfold(%s) => %ld\n", var->var_decl->identifier, constfold(var->init));
    }
    break;
  }
	case NODE_TYPE_STATEMENTS: {
		Statements *statements = (Statements *)node->data;
		Statements *st = statements;
		for (; st != NULL; st = st->next) {
			if (st->next != NULL) {
				printf("%s%sStatements:\n", prefix, arrow);
				sprintf(next_prefix, "%s%s", prefix, segment);
			} else {
				printf("%s%sStatements:\n", prefix, end_arrow);
				sprintf(next_prefix, "%s%s", prefix, end_segment);
			}
			print_walk(st->statement, next_prefix);
		}
		break;
	}
  default:
    printf("Unknown node type %d %#x\n", node->type, node->type);
    break;
  }
	free(next_prefix);
}

void print_node_tree(Node *node) {
	print_walk(node, "");
}

/*
 * Frees the memory of node recursively
 */
void finalize_tree(Node *node) {
	if (node == NULL)
		return;

	switch (node->type) {
  case NODE_TYPE_BINOP: {
    BinaryOp *binop = (BinaryOp *)node->data;
    if (binop != NULL) {
			finalize_tree(binop->left);
			finalize_tree(binop->right);
			free(binop);
    }
    break;
  }
	case NODE_TYPE_VALUE: {
		Value *value = (Value *)node->data;
		if (value != NULL) {
			if (value->typeinfo == TYPE_STRING && value->data != NULL) {
				// INVARIANT: string MUST be heap-allocated.
			 	free(value->data);
			}
			free(value);
		}
		break;
	}
	case NODE_TYPE_VARDECL: {
		VariableDeclaration *var_decl = node->data;
		if (var_decl != NULL) {
			free(var_decl->identifier);
			free(var_decl);
		}
		break;
	}
  case NODE_TYPE_VAR: {
    Variable *var = (Variable *)node->data;
    if (var != NULL) {
			Node *vd = make_node(NODE_TYPE_VARDECL);
			vd->data = var->var_decl;
			finalize_tree(var->init);

			finalize_tree(vd);
			free(var);
    }
    break;
  }
	case NODE_TYPE_STATEMENTS: {
		Statements *statements = node->data;
		if (statements != NULL) {
			Node *s = make_node(NODE_TYPE_STATEMENTS);
			s->data = statements->next;
			finalize_tree(s);
			finalize_tree(statements->statement);
			free(statements);
		}
		break;
	}
  default:
    printf("Unknown node type when trying to free: %d\n", node->type);
		break;
	}
	free(node);
}
