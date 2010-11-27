%{
#include "decafexpr-codegen-defs.h"
#include <iostream>
#include <stdexcept>

#define _DEBUG_ON

#ifdef _DEBUG_ON
#define DEBUG(stmt) stmt;
#else
#define DEBUG(stmt) ;
#endif

  using namespace std;

  semantics sem;

  attribute *constant(string *immvalue) {
    attribute *attr = new attribute;
    attr->token = string("constant");
    attr->lexeme = *immvalue;
    attr->imm = *immvalue;
    attr->opcode_type = "imm";
    attr->opcode = "li";
    attr->rdest = attr->first_free_register();
    attr->remove_first_free_register();
    attr->mipsInstruction();
    DEBUG(attr->print("constant"));
    return attr;
  }

  attribute *combine(attribute *attr, attribute *attrlist) {
    if (attrlist == NULL) {
      return attr;
    } else {
      attribute *parent = new attribute;
      parent->token = attr->token;
      parent->lexeme = attr->lexeme;
      parent->opcode_type = "none";
      parent->add_child(*attr);
      parent->add_child(*attrlist);
      DEBUG(parent->print("combine"));
      return parent;
    }
  }

  attribute *combine_args(attribute *arg, attribute *arg_list) {
    if (arg_list == NULL) {
      return arg;
    } else {
      attribute *parent = new attribute;
      parent->opcode_type = "none";
      parent->rdest = arg->rdest;
      parent->add_child(*arg);
      parent->add_child(*arg_list);
      DEBUG(parent->print("combine_args"));
      return parent;
    }
  }

  attribute *var_decl(string *attr, attribute *var_decl_list) {
    attribute *var_decl = new attribute;
    var_decl->token = string("var_decl");
    var_decl->lexeme = *attr;
    var_decl->opcode_type = "none";
    if (var_decl_list != NULL)
      var_decl->add_child(*var_decl_list);
    return var_decl;
  }

  attribute *assign(attribute *attr, attribute *expr) {
    descriptor *d = sem.access_symtbl(attr->lexeme);
    string reg;
    if (d != NULL) {
      if ((d->rdest == "") || (d->rdest.empty())) {
	reg = sem.first_symbol_register();
	sem.remove_first_symbol_register();
	d->rdest = reg;
      } else {
	reg = d->rdest;
      }
    } else {
      cerr << "variable " << attr->lexeme << " used before it was defined" << endl;
      throw runtime_error("variable not in symbol table");
    }

    attribute *assign = new attribute;
    assign->opcode_type = "load";
    assign->opcode = "move";
    assign->rdest = reg;
    assign->rsrc = expr->rdest;
    assign->add_child(*attr);
    assign->add_child(*expr);
    DEBUG(assign->print("assign"));
    return assign;
  }

  attribute *callout(string *callout_fn, attribute *attr) {
    attribute *syscall_setup = new attribute;
    syscall_setup->rdest = "$v0";
    syscall_setup->imm = "_ERROR_";

    if (*callout_fn == "\"print_int\"")
      syscall_setup->imm = "1";
    if (*callout_fn == "\"read_int\"")
      syscall_setup->imm = "5";
    if (*callout_fn == "\"print_string\"")
      syscall_setup->imm = "4";

    if (syscall_setup->imm == "_ERROR_") {
      cerr << "callout function " << *callout_fn << " is not supported" << endl;
      throw runtime_error("callout function not supported");
    }

    syscall_setup->opcode_type = "imm";
    syscall_setup->opcode = "li";

    attribute *callout = new attribute;
    callout->rdest = "$a0";
    callout->rsrc = attr->rdest;
    callout->opcode_type = "load";
    callout->opcode = "move";

    attribute *syscall = new attribute;
    syscall->opcode_type = "none";
    syscall->opcode = "syscall";
    syscall->add_child(*attr);
    syscall->add_child(*syscall_setup);
    syscall->add_child(*callout);

    DEBUG(syscall->print("callout"));
    return syscall;
  }

  attribute *expr_lvalue(attribute *token) {
    descriptor *d = sem.access_symtbl(token->lexeme);
    string reg;
    if (d != NULL) {
      if ((d->rdest == "") || (d->rdest.empty())) {
        cerr << "variable " << token->lexeme << " used before a value was assigned" << endl;
        throw runtime_error("variable not in symbol table");
      } else {
	reg = d->rdest;
      }
    } else {
      cerr << "variable " << token->lexeme << " used before it was defined" << endl;
      throw runtime_error("variable not in symbol table");
    }

    attribute *lvalue = new attribute;
    lvalue->opcode_type = "none";
    lvalue->rdest = reg;
    lvalue->add_child(*token);
    DEBUG(lvalue->print("lvalue_expr"));
    return lvalue;
  }

  attribute *binop_expr(const char *opcode, attribute *left_expr, attribute *right_expr) {
    attribute *expr = new attribute;
    expr->opcode_type = "reuse";

    if ((left_expr->rdest == "") || (left_expr->opcode_type != "none")) {
      string left_register = expr->first_free_register();
      expr->remove_first_free_register();
      left_expr->result_register(left_register);
    }

    if ((right_expr->rdest == "") || (right_expr->opcode_type != "none")) {
      string right_register = expr->first_free_register();
      expr->remove_first_free_register();
      right_expr->result_register(right_register);
    }

    expr->rdest = left_expr->rdest;
    expr->rsrc = right_expr->rdest;
    expr->opcode = string(opcode);

    DEBUG(cerr << "left_expr: " << left_expr->asmcode());
    DEBUG(cerr << "right_expr: " << right_expr->asmcode());

    expr->add_child(*left_expr);
    expr->add_child(*right_expr);
    DEBUG(expr->print("expr"));

    return expr;
  }

  attribute *unary_expr(const char *opcode, attribute *attr) {
    attribute *unary_expr = new attribute;
    string rdest = unary_expr->first_free_register();
    unary_expr->remove_first_free_register();

    if (attr->rdest == "") {
      string attr_reg = unary_expr->first_free_register();
      unary_expr->remove_first_free_register();
      attr->result_register(attr_reg);
    }

    unary_expr->rdest = rdest;
    unary_expr->rsrc = attr->rdest;

    unary_expr->opcode_type = "load";
    unary_expr->opcode = string(opcode);
    unary_expr->add_child(*attr);
    DEBUG(unary_expr->print("unary_expr"));

    return unary_expr;
  }

%}

%union {
  string *sval;
  attribute *attr;
}

%token <sval> T_AND
%token <sval> T_ASSIGN
%token <sval> T_BOOL
%token <sval> T_BREAK
%token <sval> T_CALLOUT
%token <sval> T_CHARCONSTANT
%token <sval> T_CLASS
%token <sval> T_COMMENT
%token <sval> T_COMMA
%token <sval> T_CONTINUE
%token <sval> T_DIV
%token <sval> T_DOT
%token <sval> T_ELSE
%token <sval> T_EQ
%token <sval> T_EXTENDS
%token <sval> T_FALSE
%token <sval> T_FOR
%token <sval> T_GEQ
%token <sval> T_GT
%token <sval> T_IF
%token <sval> T_INTCONSTANT
%token <sval> T_INT
%token <sval> T_LCB
%token <sval> T_LEFTSHIFT
%token <sval> T_LEQ
%token <sval> T_LPAREN
%token <sval> T_LSB
%token <sval> T_LT
%token <sval> T_MINUS
%token <sval> T_MOD
%token <sval> T_MULT
%token <sval> T_NEQ
%token <sval> T_NEW
%token <sval> T_NOT
%token <sval> T_NULL
%token <sval> T_OR
%token <sval> T_PLUS
%token <sval> T_RCB
%token <sval> T_RETURN
%token <sval> T_RIGHTSHIFT
%token <sval> T_ROT
%token <sval> T_RPAREN
%token <sval> T_RSB
%token <sval> T_SEMICOLON
%token <sval> T_STRINGCONSTANT
%token <sval> T_TRUE
%token <sval> T_VOID
%token <sval> T_WHILE
%token <sval> T_ID
%token <sval> T_WHITESPACE

%type <attr> begin_block
%type <attr> end_block
%type <attr> int_id_comma_list
%type <attr> bool_id_comma_list

%type <attr> assign
%type <attr> assign_comma_list
%type <attr> block
%type <attr> callout_arg
%type <attr> callout_arg_comma_list
%type <attr> class_name
%type <attr> constant
%type <attr> expr
%type <attr> expr_comma_list
%type <attr> field
%type <attr> field_decl
%type <attr> field_decl_list
%type <attr> field_list
%type <attr> lvalue
%type <attr> method_call
%type <attr> method_decl
%type <attr> method_decl_list
%type <attr> opt_expr
%type <attr> param
%type <attr> param_comma_list
%type <attr> param_list
%type <attr> program
%type <attr> statement
%type <attr> statement_list
%type <attr> type
%type <attr> var_decl
%type <attr> var_decl_list

%type <attr> start

%left T_OR
%left T_AND
%left T_EQ T_NEQ
%left T_LT T_LEQ T_GEQ T_GT
%left T_LEFTSHIFT T_RIGHTSHIFT T_ROT
%left T_MOD
%left T_PLUS T_MINUS
%left T_MULT T_DIV
%left T_NOT
%right UMINUS

%%

start: program
  {
    // cout << sem.final(*$1) << endl;
    // $1->printtree(0);
    // delete $1;
  }

program: T_CLASS class_name T_LCB field_decl_list method_decl_list T_RCB
  {
    cout << "Reduce: program\n"; 
  }
     | T_CLASS class_name T_LCB field_decl_list T_RCB
  {
  }
     ;

class_name: T_ID
  {
  }

block: begin_block var_decl_list statement_list end_block
  {
    delete $2;
    $$ = $3;
  }

begin_block: T_LCB
  {
    sem.new_symtbl();
  }

end_block: T_RCB
  {
    sem.remove_symtbl();
  }

field_decl_list: field_decl_list field_decl
  {
  }
     | /* empty */ 
  {
  }
     ;

field_decl: type field_list T_SEMICOLON
    {
    }
     | type T_ID T_ASSIGN constant T_SEMICOLON
    {
    }
     ;

field_list: field T_COMMA field_list
    {
    }
     | field
    {
    }
     ;

field: T_ID
    {
    }
     | T_ID T_LSB T_INTCONSTANT T_RSB
    {
    }
     ;

method_decl_list: method_decl_list method_decl
  {
  }
     | method_decl
  {
  }
     ;


method_decl: T_VOID T_ID T_LPAREN param_list T_RPAREN block
    {
    }
     | type T_ID T_LPAREN param_list T_RPAREN block
    {
    }
     ;

param_list: param_comma_list
  {
  }
     | /* empty */
  {
  }
     ;

param_comma_list: param T_COMMA param_comma_list
  {
  }
     | param
  {
  }
     ;

param: type T_ID
  {
  }
     ;

type: T_INT
  {
  }
     | T_BOOL
  {
  }
     ;

var_decl_list: var_decl var_decl_list
  {
    $$ = combine($1, $2);
  }
     | /* empty */
  {
    $$ = NULL;
  }
     ;

statement_list: statement statement_list
  {
    $$ = combine($1, $2);
  }
     | /* empty */ 
  {
    $$ = NULL;
  }
     ;

var_decl: T_INT T_ID int_id_comma_list T_SEMICOLON
  {
    sem.enter_symtbl(*$2, *$1, "", "");
    $$ = var_decl($2, $3);
  }
     | T_BOOL T_ID bool_id_comma_list T_SEMICOLON
  {
    sem.enter_symtbl(*$2, *$1, "", "");
    $$ = var_decl($2, $3);
  }

int_id_comma_list: /* empty */ 
  {
    $$ = NULL;
  }
     | T_COMMA T_ID int_id_comma_list
  {
    sem.enter_symtbl(*$2, string("int"), "", "");
    $$ = var_decl($2, $3);
  }
     ;

bool_id_comma_list: /* empty */ 
  {
    $$ = NULL;
  }
     | T_COMMA T_ID bool_id_comma_list
  {
    sem.enter_symtbl(*$2, string("bool"), "", "");
    $$ = var_decl($2, $3);
  }
     ;

statement: assign T_SEMICOLON
  {
    $$ = $1;
  }
     | method_call T_SEMICOLON
  {
    $$ = $1;
  }
     | T_IF T_LPAREN expr T_RPAREN block T_ELSE block
  {
  }
     | T_IF T_LPAREN expr T_RPAREN block 
  {
  }
     | T_WHILE T_LPAREN expr T_RPAREN block
  {
  }
     | T_FOR T_LPAREN assign_comma_list T_SEMICOLON expr T_SEMICOLON assign_comma_list T_RPAREN block
  {
  }
     | T_RETURN opt_expr T_SEMICOLON
  {
  }
     | T_BREAK T_SEMICOLON
  {
  }
     | T_CONTINUE T_SEMICOLON
  {
  }
     | block
  {
    $$ = $1;
  }
     ;

assign: lvalue T_ASSIGN expr
  {
    $$ = assign($1, $3);
  }

method_call: T_ID T_LPAREN expr_comma_list T_RPAREN
  {
  
  }
           | T_CALLOUT T_LPAREN T_STRINGCONSTANT callout_arg_comma_list T_RPAREN
  {
    $$ = callout($3, $4);
  };

assign_comma_list: assign
  {
  }
     | assign T_COMMA assign_comma_list
  {
  }
     ;

expr_comma_list: opt_expr
  {
  }
     | expr T_COMMA expr_comma_list
  {
  }
     ;

opt_expr: expr
  {
  }
     | /* empty */ 
  {
  }
     ;

callout_arg_comma_list: T_COMMA callout_arg callout_arg_comma_list
  {
    $$ = combine_args($2, $3);
  }
     | /* empty */ 
  {
    $$ = NULL;
  }
     ;

callout_arg: expr
  {
    $$ = $1;
  }
     | T_STRINGCONSTANT
  {
    attribute *stringconst = new attribute;
    stringconst->token = string("stringconst");
    stringconst->lexeme = *$1;
    $$ = stringconst;
  }
     ;

lvalue: T_ID
  {
    attribute *lvalue = new attribute;
    lvalue->token = string("lvalue");
    lvalue->lexeme = *$1;
    $$ = lvalue;
  }
     ;

expr: lvalue
  {
    $$ = expr_lvalue($1);
  }
     | method_call
  {
    $$ = $1;
  }
     | constant
  {
    $$ = $1;
  }
     | expr T_PLUS expr
  {
    $$ = binop_expr("addu", $1, $3);
  }
     | expr T_MINUS expr
  {
    $$ = binop_expr("subu", $1, $3);
  }
     | expr T_MULT expr
  {
    $$ = binop_expr("mul", $1, $3);
  }
     | expr T_DIV expr
  {
    $$ = binop_expr("divu", $1, $3);
  }
     | expr T_LEFTSHIFT expr
  {
    $$ = binop_expr("sllv", $1, $3);
  }
     | expr T_RIGHTSHIFT expr
  {
    $$ = binop_expr("srlv", $1, $3);
  }
     | expr T_ROT expr
  {
    // this should include either a mod instruction or a branch,
    // removed the correct implementation here due to overlap with hw4
    if ($3->opcode == "neg") {
      $$ = binop_expr("ror", $1, $3); // rotate right if right expr is -1
    } else {
      $$ = binop_expr("ror", $1, $3); // else rotate left
    }
  }
     | expr T_MOD expr
  {
    $$ = binop_expr("rem", $1, $3);
  }
     | expr T_LT expr
  {
    $$ = binop_expr("slt", $1, $3);
  }
     | expr T_GT expr
  {
    $$ = binop_expr("sge", $1, $3);
  }
     | expr T_LEQ expr
  {
    $$ = binop_expr("sle", $1, $3);
  }
     | expr T_GEQ expr
  {
    $$ = binop_expr("sgeu", $1, $3);
  }
     | expr T_EQ expr
  {
    $$ = binop_expr("seq", $1, $3);
  }
     | expr T_NEQ expr
  {
    $$ = binop_expr("sne", $1, $3);
  }
     | expr T_AND expr
  {
    $$ = binop_expr("and", $1, $3);
  }
     | expr T_OR expr
  {
    $$ = binop_expr("or", $1, $3);
  }
     | T_MINUS expr %prec UMINUS 
  {
    $$ = unary_expr("neg", $2);
  }
     | T_NOT expr
  {
    attribute *imm = new attribute;
    imm->opcode_type = string("none");
    imm->rdest = string("0");
    $$ = binop_expr("seq", $2, imm);
  }
     | T_LPAREN expr T_RPAREN
  {
    $$ = $2;
  }
     ;

constant: T_INTCONSTANT
  {
    $$ = constant($1);
  }
     | T_CHARCONSTANT
  {
    $$ = constant($1);
  }
     | T_TRUE
  {
    string trueval("1");
    $$ = constant(&trueval);
  }
     | T_FALSE
  {
    string falseval("0");
    $$ = constant(&falseval);
  }
     ;


%%


