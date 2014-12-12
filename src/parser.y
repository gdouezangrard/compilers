%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <search.h>
    #include <string.h>
    #include "parser.tab.h"

    #define REGISTERS 6
    #define IDENTIFIERS 20

    extern int yylineno;
    int yylex();
    int yyerror();

    typedef struct id_s {
        char *s;
        int t;
    } id_type;

    char *registers[REGISTERS] = {"%eax", "%ebx", "%ecx", "%edx", "%esi", "%edi"};
    int registers_free[REGISTERS] = {1, 1, 1, 1, 1, 1};
    int l_vars = 0;
    int f_vars = 0;
    int r_vars;
    id_type *identifiers[IDENTIFIERS];

    int find_id(char *s) {
        int i;
        for (i = 0; i < l_vars; i++) {
            if(strcmp(identifiers[i]->s, s) == 0) {
                return i;
            }
        }
        return -1;
    }

    void new_id(char *s, int t) {
        if (find_id(s) == -1) {
            id_type *id = malloc(sizeof(id_t));
            id->s = s;
            id->t = t;
            identifiers[l_vars++] = id;
        }
    }

    typedef struct node_s {
        int type; // kind of operation, or leaf
        struct node_s *left, *right, *extra1, *extra2; // NULL if leaf, extra1 for IF, extra1/2 for FOR
        int id_type;
        int reg;
        union {
            int i;
            float f;
            char *s;
        } leaf;
    } node_t;

    int take() {
        int i;
        for (i = 0; i < REGISTERS; i++) {
            if (registers_free[i]) {
                registers_free[i] = 0;
                return i;
            }
        }
        return -1;
    }

    void give(int i) {
        if (i >= 0 && i < REGISTERS) {
            registers_free[i] = 1;
        }
    }

    char *reg(int i) {
        if (i >= 0 && i < REGISTERS) {
            return registers[i];
        }
        return NULL;
    }

    node_t *node(int type, node_t *left, node_t *right) {
        node_t *n = malloc(sizeof(node_t));
        n->type = type;
        n->left = left;
        n->right = right;
        return n;
    }

    node_t *node_extra(int type, node_t *left, node_t *right, node_t *extra1, node_t *extra2) {
        node_t *n = malloc(sizeof(node_t));
        n->type = type;
        n->left = left;
        n->right = right;
        n->extra1 = extra1;
        n->extra2 = extra2;
        return n;
    }

    node_t *node_fcall(char *s, node_t *left) {
        node_t *n = malloc(sizeof(node_t));
        n->type = FCALL; // for leaf of type string (identifier)
        n->leaf.s = s;
        n->left = left;
        int i = find_id(s);
        if (i != -1) {
            if (identifiers[i]->t != FUNCTION) {
                identifiers[i]->t = FUNCTION;
                f_vars++;
            }
        }
        return n;
    }

    node_t *node_i(int i) {
        node_t *n = malloc(sizeof(node_t));
        n->type = ICONSTANT; // for leaf of type integer
        n->leaf.i = i;
        n->left = n->right = NULL;
        return n;
    }

    node_t *node_f(float f) {
        node_t *n = malloc(sizeof(node_t));
        n->type = FCONSTANT; // for leaf of type float
        n->leaf.f = f;
        n->left = n->right = NULL;
        return n;
    }

    node_t *node_s(char *s) {
        node_t *n = malloc(sizeof(node_t));
        n->type = IDENTIFIER; // for leaf of type string (identifier)
        n->leaf.s = s;
        n->left = n->right = NULL;
        new_id(s, -1);
        return n;
    }

    void asm_type(node_t *n) {
        switch (n->type) {
            case ICONSTANT:
                printf("$%i", n->leaf.i);
                break;
            case IDENTIFIER:
                printf("%i(%%rbp)", -4*(find_id(n->leaf.s)+1-f_vars));
                break;
            case REGISTER:
                printf("%%%s", n->leaf.s);
                break;
        }
    }

    void mov(node_t *left, node_t *right) {
        printf("\tmov\t");asm_type(left);printf(",");asm_type(right);printf("\n");
    }

    void print_node(node_t *n) {
        int i;
        int j;
        switch (n->type) {
            case ICONSTANT:
                printf("$%d", n->leaf.i);
                break;
            case '+':
                switch (n->left->type) {
                    case IDENTIFIER:
                        i = take();
                        n->left->reg = i;
                        printf("\tmov\t%i(%%rbp),%s\n", -4*(find_id(n->left->leaf.s)-f_vars), reg(i));
                        break;
                    case ICONSTANT:
                    case FCONSTANT:
                        i = take();
                        printf("\tmov\t");asm_type(n);printf(",");printf("%s\n", reg(i));
                        break;
                    default:
                        print_node(n->left);
                }
                switch (n->right->type) {
                    case IDENTIFIER:
                        j = take();
                        n->right->reg = j;
                        printf("\tmov\t%i(%%rbp),%s\n", -4*(find_id(n->right->leaf.s)-f_vars), reg(n->right->reg));
                        break;
                    case ICONSTANT:
                    case FCONSTANT:
                        j = take();
                        printf("\tmov\t");asm_type(n);printf(",");printf("%s\n", reg(j));
                        break;
                    default:
                        print_node(n->right);
                }
                printf("\tadd\t%s,%s", reg(n->left->reg), reg(n->right->reg));printf("\n");
                n->reg = j;
                give(i);
                break;
            case '-':
                switch (n->left->type) {
                    case IDENTIFIER:
                        i = take();
                        n->left->reg = i;
                        printf("\tmov\t%i(%%rbp),%s\n", -4*(find_id(n->left->leaf.s)-f_vars), reg(i));
                        break;
                    case ICONSTANT:
                    case FCONSTANT:
                        i = take();
                        printf("\tmov\t");asm_type(n);printf(",");printf("%s\n", reg(i));
                        break;
                    default:
                        print_node(n->left);
                }
                switch (n->right->type) {
                    case IDENTIFIER:
                        j = take();
                        n->right->reg = j;
                        printf("\tmov\t%i(%%rbp),%s\n", -4*(find_id(n->right->leaf.s)-f_vars), reg(n->right->reg));
                        break;
                    case ICONSTANT:
                    case FCONSTANT:
                        j = take();
                        printf("\tmov\t");asm_type(n);printf(",");printf("%s\n", reg(j));
                        break;
                    default:
                        print_node(n->right);
                }
                printf("\tsub\t%s,%s", reg(n->left->reg), reg(n->right->reg));printf("\n");
                n->reg = j;
                give(i);
                break;
            case '*':
                switch (n->left->type) {
                    case IDENTIFIER:
                        i = take();
                        n->left->reg = i;
                        printf("\tmov\t%i(%%rbp),%s\n", -4*(find_id(n->left->leaf.s)-f_vars), reg(i));
                        break;
                    case ICONSTANT:
                    case FCONSTANT:
                        i = take();
                        printf("\tmov\t");asm_type(n);printf(",");printf("%s\n", reg(i));
                        break;
                    default:
                        print_node(n->left);
                }
                switch (n->right->type) {
                    case IDENTIFIER:
                        j = take();
                        n->right->reg = j;
                        printf("\tmov\t%i(%%rbp),%s\n", -4*(find_id(n->right->leaf.s)-f_vars), reg(n->right->reg));
                        break;
                    case ICONSTANT:
                    case FCONSTANT:
                        j = take();
                        printf("\tmov\t");asm_type(n);printf(",");printf("%s\n", reg(j));
                        break;
                    default:
                        print_node(n->right);
                }
                printf("\tmul\t%s,%s", reg(n->left->reg), reg(n->right->reg));printf("\n");
                n->reg = j;
                give(i);
                break;
            case '=':
                i = -1;
                switch (n->right->type) {
                    case IDENTIFIER:
                    case ICONSTANT:
                    case FCONSTANT:
                        i = take();
                        printf("\tmov\t");asm_type(n->right);printf(",%s", reg(i));printf("\n");
                        break;
                    default:
                        print_node(n->right);
                        i = n->right->reg;
                }
                printf("\tmov\t%s,", reg(i));print_node(n->left);
                give(i);
                break;
            case IDENTIFIER:
                printf("%i(%%rbs)", -4*(find_id(n->leaf.s)-f_vars));
                break;
            case ';':
                print_node(n->left);printf("\n");print_node(n->right);
                break;
            case ',':
                print_node(n->left);printf(", ");print_node(n->right);
                break;
            case FUNCTION:
                printf("\t.globl\t");printf("%s", n->left->leaf.s);printf("\n");
                printf(":");printf("%s", n->left->leaf.s);printf("\n");
                printf("\tpushq\t%%rbp\n");
                printf("\tmovq\t%%rsp,%%rbp\n");
                printf("\tsubq\t$%i,%%rsp\n", 4*(l_vars-f_vars-1));
                print_node(n->right);printf("\n");
                printf("\taddq\t$%i,%%rsp\n", 4*(l_vars-f_vars-1));
                printf("\tpopq\t%%rbp\n\n");
                break;
            case IF:
                printf("--if-- ");print_node(n->left);printf("\n");print_node(n->right);
                if (n->extra1 != NULL) {
                    printf("\n--else--\n");
                    print_node(n->extra1);
                }
                printf("\n");
                break;
            case FCALL:
                if (n->left != NULL) {
                    printf("%s(", n->leaf.s);print_node(n->left);printf(")\n");
                } else {
                    printf("%s()\n", n->leaf.s);
                }
                break;
            default:
                ;
        }
    }

%}

%token <str> IDENTIFIER
%token <i> ICONSTANT
%token <f> FCONSTANT
%token INC_OP DEC_OP LE_OP GE_OP EQ_OP NE_OP
%token INT FLOAT VOID
%token IF ELSE WHILE RETURN FOR
%token FUNCTION FCALL REGISTER
%type <n> primary_expression expression comparison_expression additive_expression multiplicative_expression unary_expression compound_statement statement_list statement expression_statement declarator_list declarator declaration function_definition selection_statement argument_expression_list
%union {
  char *str;
  int i;
  float f;
  struct node_s *n;
}
%start program
%%

primary_expression
: IDENTIFIER                                    { $$ = node_s($1); }
| ICONSTANT                                     { $$ = node_i($1); }
| FCONSTANT                                     { $$ = node_f($1); }
| '(' expression ')'                            { $$ = $2; }
| IDENTIFIER '(' ')'                            { $$ = node_fcall($1, NULL); }
| IDENTIFIER '(' argument_expression_list ')'   { $$ = node_fcall($1, $3); }
/*| IDENTIFIER INC_OP*/
/*| IDENTIFIER DEC_OP*/
/*| IDENTIFIER '[' expression ']'*/
;

argument_expression_list
: expression                                { $$ = $1; }
| argument_expression_list ',' expression   { $$ = node(',', $1, $3); }
;

unary_expression
: primary_expression        { $$ = $1; }
/*| '-' unary_expression*/
/*| '!' unary_expression*/
;

multiplicative_expression
: unary_expression                                  { $$ = $1; }
| multiplicative_expression '*' unary_expression    { $$ = node('*', $1, $3); }
;

additive_expression
: multiplicative_expression                             { $$ = $1; }
| additive_expression '+' multiplicative_expression     { $$ = node('+', $1, $3); }
| additive_expression '-' multiplicative_expression     { $$ = node('-', $1, $3); }
;

comparison_expression
: additive_expression                                   { $$ = $1; }
/*| additive_expression '<' additive_expression*/
/*| additive_expression '>' additive_expression*/
/*| additive_expression LE_OP additive_expression*/
/*| additive_expression GE_OP additive_expression*/
/*| additive_expression EQ_OP additive_expression*/
/*| additive_expression NE_OP additive_expression*/
;

expression
: IDENTIFIER '=' comparison_expression                          { $$ = node('=', node_s($1), $3); }
/*| IDENTIFIER '[' expression ']' '=' comparison_expression*/
| comparison_expression                                         { $$ = $1; }
;

declaration
: type_name declarator_list ';'     { $$ = $2; }
;

declarator_list
: declarator                            { $$ = $1; }
/*| declarator_list ',' declarator*/
;

type_name
: VOID
| INT
| FLOAT
;

declarator
: IDENTIFIER                            { $$ = node_s($1); }
| '*' IDENTIFIER                        { $$ = node_s($2); }
/*| IDENTIFIER '[' ICONSTANT ']'*/
/*| declarator '(' parameter_list ')'*/
| declarator '(' ')'                    { $$ = $1; }
;

/*parameter_list*/
/*: parameter_declaration*/
/*| parameter_list ',' parameter_declaration*/
/*;*/

/*parameter_declaration*/
/*: type_name declarator*/
/*;*/

statement
: compound_statement        { $$ = $1; }
| expression_statement      { $$ = $1; }
| selection_statement       { $$ = $1; }
/*| iteration_statement*/
/*| jump_statement*/
;

compound_statement
: '{' '}'                                   { $$ = NULL; }
| '{' statement_list '}'                    { $$ = $2; }
/*| '{' declaration_list statement_list '}'*/
;

/*declaration_list*/
/*: declaration*/
/*| declaration_list declaration*/
/*;*/

statement_list
: statement                 { $$ = $1; }
| statement_list statement  { $$ = node(';', $1, $2); }
;

expression_statement
: ';'                   { $$ = NULL; }
| expression ';'        { $$ = $1; }
;

selection_statement
: IF '(' expression ')' statement                       { $$ = node_extra(IF, $3, $5, NULL, NULL); }
| IF '(' expression ')' statement ELSE statement        { $$ = node_extra(IF, $3, $5, $7, NULL); }
;

/*iteration_statement*/
/*: WHILE '(' expression ')' statement*/
/*| FOR '(' expression_statement expression_statement expression ')' statement*/
/*;*/

/*jump_statement*/
/*: RETURN ';'
/*| RETURN expression ';'*/
/*;*/

program
: external_declaration
| program external_declaration
;

external_declaration
: function_definition       { hcreate(30); r_vars = l_vars - f_vars; print_node($1); hdestroy(); l_vars = f_vars; }
| declaration
;

function_definition
: type_name declarator compound_statement   { $$ = node(FUNCTION, $2, $3); }
;

%%
#include <stdio.h>
#include <string.h>

extern char yytext[];
extern int column;
extern int yylineno;
extern FILE *yyin;

char *file_name = NULL;

int yyerror(char *s) {
    fflush(stdout);
    fprintf(stderr, "%s:%d:%d: %s\n", file_name, yylineno, column, s);
    return 0;
}


int main(int argc, char *argv[]) {
    FILE *input = NULL;
    if (argc==2) {
        input = fopen(argv[1], "r");
        file_name = strdup(argv[1]);
        if (input) {
            yyin = input;
            printf("\t.text\n");
            yyparse();
        }
        else {
            fprintf(stderr, "%s: Could not open %s\n", *argv, argv[1]);
            return 1;
        }
        free(file_name);
    }
    else {
        fprintf(stderr, "%s: error: no input file\n", *argv);
        return 1;
    }
    return 0;
}
