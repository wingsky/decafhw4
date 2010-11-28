
#ifndef _DECAFEXPR_CODEGEN_DEFS
#define _DECAFEXPR_CODEGEN_DEFS

#include <string>
#include "descriptor.cc"
#include "attribute.cc"
#include "semantics.cc"
#include "code.cc"

using namespace std;

extern int lineno;
extern int tokenpos;

extern "C"
{
  extern int yyerror(const char *);
  int yyparse(void);
  int yylex(void);  
  int yywrap(void);
}

#endif

