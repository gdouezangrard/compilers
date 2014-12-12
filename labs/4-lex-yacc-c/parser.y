%{
    #include <stdio.h>
    extern int yylineno;
    int yylex ();
    int yyerror ();
    typedef enum {INT_T,FLOAT_T} btype_t;
    typedef enum {ESCALAR_T, ARRAY_T,FUNCTION_T} kind_t;
    typedef structure {kind_t kind;
      btype_t btype;
      char is_starred; //is pointer ?
      int size; // is it an array ? or a function ?
      struct type_s * parameters; //.. it is a function with params
    } type_t;
%}

%token <str> IDENTIFIER ICONSTANT FCONSTANT
%token INC_OP DEC_OP LE_OP GE_OP EQ_OP NE_OP
%token INT FLOAT VOID
%token IF ELSE WHILE RETURN FOR DO
%type <type> declarator
%union {
  char *str;
  type_t type;
}
%start program
%%

primary_expression
: IDENTIFIER {printf("%s\n",$1);} 
| ICONSTANT  {printf("%s\n",$1);}
| FCONSTANT  {printf("%s\n",$1);}
| '(' expression ')'
| IDENTIFIER '(' ')'  {printf("%s\n",$1);}
| IDENTIFIER '(' argument_expression_list ')' {printf("%s\n",$1);}
| IDENTIFIER INC_OP {printf("%s\n",$1);}
| IDENTIFIER DEC_OP {printf("%s\n",$1);}
| IDENTIFIER '[' expression ']'  {printf("%s\n",$1);}
;

argument_expression_list
: expression
| argument_expression_list ',' expression
;

unary_expression
: primary_expression
| '-' unary_expression
| '!' unary_expression
;

multiplicative_expression
: unary_expression
| multiplicative_expression '*' unary_expression
;

additive_expression
: multiplicative_expression
| additive_expression '+' multiplicative_expression
| additive_expression '-' multiplicative_expression
;

comparison_expression
: additive_expression
| additive_expression '<' additive_expression
| additive_expression '>' additive_expression
| additive_expression LE_OP additive_expression
| additive_expression GE_OP additive_expression
| additive_expression EQ_OP additive_expression
| additive_expression NE_OP additive_expression
;

expression
: IDENTIFIER '=' comparison_expression  {printf("%s\n",$1);}
| IDENTIFIER '[' expression ']' '=' comparison_expression {printf("%s\n",$1);}
| comparison_expression
;

declaration
: type_name declarator_list ';'
;

declarator_list
: declarator {printf("declarator%s\n",$1);}
| declarator_list ',' declarator {printf("declarator%s\n",$3);}
;

type_name
: VOID 
| INT  
| FLOAT
;

declarator
: IDENTIFIER    {printf("%s\n",$1); }
| '*' IDENTIFIER  {printf("%s\n",$2);}
| IDENTIFIER '[' ICONSTANT ']'  {printf("%s\n",$1); printf("%s\n",$3);} 
| declarator '(' parameter_list ')' {printf("declarator%s\n",$1);}
| declarator '(' ')' {printf("declarator%s\n",$1);}
;

parameter_list
: parameter_declaration
| parameter_list ',' parameter_declaration
;

parameter_declaration
: type_name declarator {printf("declarator%s\n",$2);}
;

statement
: compound_statement
| expression_statement 
| selection_statement
| iteration_statement
| jump_statement
;

compound_statement
: '{' '}'
| '{' statement_list '}'
| '{' declaration_list statement_list '}'
;

declaration_list
: declaration
| declaration_list declaration
;

statement_list
: statement
| statement_list statement
;

expression_statement
: ';'
| expression ';'
;

selection_statement
: IF '(' expression ')' statement
| IF '(' expression ')' statement ELSE statement
;

iteration_statement
: DO '{' statement '}' WHILE '(' expression ')' ';'
| WHILE '(' expression ')' statement
| FOR '(' expression_statement expression_statement expression ')' statement
;

jump_statement
: RETURN ';'
| RETURN expression ';'
;

program
: external_declaration
| program external_declaration
;

external_declaration
: function_definition
| declaration
;

function_definition
: type_name declarator compound_statement
;

%%
#include <stdio.h>
#include <string.h>

extern char yytext[];
extern int column;
extern int yylineno;
extern FILE *yyin;

char *file_name = NULL;

int yyerror (char *s) {
    fflush (stdout);
    fprintf (stderr, "%s:%d:%d: %s\n", file_name, yylineno, column, s);
    return 0;
}


int main (int argc, char *argv[]) {
    FILE *input = NULL;
    if (argc==2) {
	input = fopen (argv[1], "r");
	file_name = strdup (argv[1]);
	if (input) {
	    yyin = input;
	    yyparse();
	}
	else {
	  fprintf (stderr, "%s: Could not open %s\n", *argv, argv[1]);
	    return 1;
	}
	free(file_name);
    }
    else {
	fprintf (stderr, "%s: error: no input file\n", *argv);
	return 1;
    }
    return 0;
}
