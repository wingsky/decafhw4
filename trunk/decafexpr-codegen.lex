%{
#include "decafexpr-codegen-defs.h"
#include "decafexpr-codegen.tab.h"
#include <cstring>
#include <string>
#include <sstream>
#include <cstdlib>
#include <iostream>

  using namespace std;
  
  int lineno = 0;
  int tokenpos = 0;

  string *preterm(const char* token, const char* lexeme) {
    string *preterm = new string(lexeme);
    return preterm;
  }

  string remove_newlines (string s) {
    string newstring;
    for (string::iterator i = s.begin(); i != s.end(); i++) {
      switch(*i) {
      case '\n':
	lineno += 1; tokenpos = 0;
	newstring.push_back('\\');
	newstring.push_back('n');
	break;
      case '(':
	newstring.push_back('\\');
	newstring.push_back('(');
	break;
      case ')':
	newstring.push_back('\\');
	newstring.push_back(')');
	break;
      default:
	newstring.push_back(*i);
      }
    }
    return newstring;
  }

  /*
  string remove_newlines (string s) {
    string newstring;
    for (string::iterator i = s.begin(); i != s.end(); i++) {
      if (*i == '\n') {
	lineno += 1; tokenpos = 0;
	newstring.push_back('\\');
	newstring.push_back('n');
      } else {
	newstring.push_back(*i);
      }
    }
    return newstring;
  }
  */

  string *process_token(const char *str) {
    tokenpos += yyleng;
    string lexeme(yytext);
    lexeme = remove_newlines(lexeme);
    return preterm(str, lexeme.c_str());
  }

  void process_ws() {
    tokenpos += yyleng;
    string lexeme(yytext);
    lexeme = remove_newlines(lexeme);
  }

%}

chars    [ !\"#\$%&\(\)\*\+,\-\.\/0-9:;\<=>\?\@A-Z\[\]\^\_\`a-z\{\|\}\~\t\v\r\n\a\f\b]
charesc  \\[\'tvrnafb\\]
stresc   \\[\'\"tvrnafb\\]
notstresc \\[^\'\"tvrnafb\\]

%%
  /*
    Pattern definitions for all tokens 
  */
&&                         { yylval.sval = process_token("T_AND"); return T_AND; }
=                          { yylval.sval = process_token("T_ASSIGN"); return T_ASSIGN; }
bool                       { yylval.sval = process_token("T_BOOL"); return T_BOOL; }
break                      { yylval.sval = process_token("T_BREAK"); return T_BREAK; }
callout                    { yylval.sval = process_token("T_CALLOUT"); return T_CALLOUT; }
('{chars}')|('{charesc}')  { yylval.sval = process_token("T_CHARCONSTANT"); return T_CHARCONSTANT; }
class                      { yylval.sval = process_token("T_CLASS"); return T_CLASS; }
,                          { yylval.sval = process_token("T_COMMA"); return T_COMMA; }
\/\/[^\n]*\n               { process_ws(); } /* ignore comments */
continue                   { yylval.sval = process_token("T_CONTINUE"); return T_CONTINUE; }
\/                         { yylval.sval = process_token("T_DIV"); return T_DIV; }
\.                         { yylval.sval = process_token("T_DOT"); return T_DOT; }
 else                      { yylval.sval = process_token("T_ELSE"); return T_ELSE; }
==                         { yylval.sval = process_token("T_EQ"); return T_EQ; }
extends                    { yylval.sval = process_token("T_EXTENDS"); return T_EXTENDS; }
false                      { yylval.sval = process_token("T_FALSE"); return T_FALSE; }
for                        { yylval.sval = process_token("T_FOR"); return T_FOR; }
>=                         { yylval.sval = process_token("T_GEQ"); return T_GEQ; }
>                          { yylval.sval = process_token("T_GT"); return T_GT; }
if                         { yylval.sval = process_token("T_IF"); return T_IF; }
(0x[0-9a-fA-F]+)|([0-9]+)  { yylval.sval = process_token("T_INTCONSTANT"); return T_INTCONSTANT; }
int                        { yylval.sval = process_token("T_INT"); return T_INT; }
\{                         { yylval.sval = process_token("T_LCB"); return T_LCB; }
\<\<                       { yylval.sval = process_token("T_LEFTSHIFT"); return T_LEFTSHIFT; }
\<=                        { yylval.sval = process_token("T_LEQ"); return T_LEQ; }
\(                         { yylval.sval = process_token("T_LPAREN"); return T_LPAREN; }
\[                         { yylval.sval = process_token("T_LSB"); return T_LSB; }
\<                         { yylval.sval = process_token("T_LT"); return T_LT; }
-                          { yylval.sval = process_token("T_MINUS"); return T_MINUS; }
\%                         { yylval.sval = process_token("T_MOD"); return T_MOD; }
\*                         { yylval.sval = process_token("T_MULT"); return T_MULT; }
!=                         { yylval.sval = process_token("T_NEQ"); return T_NEQ; }
new                        { yylval.sval = process_token("T_NEW"); return T_NEW; }
!                          { yylval.sval = process_token("T_NOT"); return T_NOT; }
null                       { yylval.sval = process_token("T_NULL"); return T_NULL; }
\|\|                       { yylval.sval = process_token("T_OR"); return T_OR; }
\+                         { yylval.sval = process_token("T_PLUS"); return T_PLUS; }
\}                         { yylval.sval = process_token("T_RCB"); return T_RCB; }
return                     { yylval.sval = process_token("T_RETURN"); return T_RETURN; }
>>                         { yylval.sval = process_token("T_RIGHTSHIFT"); return T_RIGHTSHIFT; }
rot                        { yylval.sval = process_token("T_ROT"); return T_ROT; }
\)                         { yylval.sval = process_token("T_RPAREN"); return T_RPAREN; }
\]                         { yylval.sval = process_token("T_RSB"); return T_RSB; }
\;                         { yylval.sval = process_token("T_SEMICOLON"); return T_SEMICOLON; }
\"([^\n\"\\]*{stresc}?)*\" { yylval.sval = process_token("T_STRINGCONSTANT"); return T_STRINGCONSTANT; }
true                       { yylval.sval = process_token("T_TRUE"); return T_TRUE; }
void                       { yylval.sval = process_token("T_VOID"); return T_VOID; }
while                      { yylval.sval = process_token("T_WHILE"); return T_WHILE; }
[a-zA-Z\_][a-zA-Z\_0-9]*   { yylval.sval = process_token("T_ID"); return T_ID; } /* note that identifier pattern must be after all keywords */
[\t\r\n\a\v\b ]+           { process_ws(); } /* ignore whitespace */
  /* 
   Error handling
   (be careful: error patterns should not match more input than a valid token)
  */
\"([^\n\"\\]*{notstresc}?)*\" { cerr << "Error: unknown escape sequence in string constant" << endl; return -1; }
\"\"\"                     { cerr << "Error: unterminated string constant" << endl; return -1; }
\"([^\n\"\\]*{stresc}?)*$  { cerr << "Error: string constant is missing closing delimiter" << endl; return -1; }
\"([^\n\"\\]*{notstresc}?\n)*\" { cerr << "Error: newline in string constant" << endl; return -1; }
'[^\\]{chars}'             { cerr << "Error: char constant length is greater than one" << endl; return -1; }
'\\'                       { cerr << "Error: unterminated char constant" << endl; return -1; }
''                         { cerr << "Error: char constant has zero width" << endl; return -1; }
.                          { cerr << "Error: unexpected character in input" << endl; return -1; }
%%

int yyerror(const char *s) {
  cerr << lineno << ": " << s << " at " << yytext << endl;
  return 0;
}

