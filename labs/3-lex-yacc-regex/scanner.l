%{
 #include<stdio.h>
%}
%option noyywrap
%%
[+-]?[0-9][0-9]*\.[0-9]*(e[+-]?[0-9][0-9]*)? {printf("%s\n",yytext);}
%%
int main () {
   yylex();
}
