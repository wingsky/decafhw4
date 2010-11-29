%{
#include "decafexpr-codegen-defs.h"
#include <iostream>
#include <stdexcept>

//#define _DEBUG_ON

#ifdef _DEBUG_ON
#define DEBUG(stmt) stmt;
#else
#define DEBUG(stmt) ;
#endif

  using namespace std;


  semantics sem;
  code g_code;
  

  attribute *constant(string *immvalue) {
    attribute *attr = new attribute;
    attr->token = string("constant");
    attr->lexeme = *immvalue;
    attr->imm = *immvalue;
    attr->opcode_type = "imm";
    attr->opcode = "li";
    attr->rdest = reg::get_temp_reg(-1, -1);
    attr->mipsInstruction();
    DEBUG(attr->print("constant"));
	g_code.add(attr->asmcode());
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
	  g_code.add(parent->asmcode());
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
	  g_code.add(parent->asmcode());
      return parent;
    }
  }

  attribute *field(string *attr) {
    attribute *field = new attribute;
    
    field->token = string("field");
    field->lexeme = *attr;
    field->opcode_type = "none";
    return field;
  }

  attribute *field_decl(string lexeme, attribute *field_decl_list) {
    attribute *field_decl = new attribute;
    field_decl->token = string("field_decl");
    field_decl->lexeme = lexeme;
    field_decl->opcode_type = "none";
    if (field_decl_list != NULL)
      field_decl->add_child(*field_decl_list);
    g_code.add(field_decl->asmcode());
    return field_decl;
  }

  attribute *var_decl(string *attr, attribute *var_decl_list) {
    attribute *var_decl = new attribute;
    var_decl->token = string("var_decl");
    var_decl->lexeme = *attr;
    var_decl->opcode_type = "none";
    if (var_decl_list != NULL)
      var_decl->add_child(*var_decl_list);
	g_code.add(var_decl->asmcode());
    return var_decl;
  }

  attribute *if_else(attribute *expr, attribute *block){
	attribute *if_else = new attribute;
	if_else->token = string("if_else");
	if_else->opcode_type = "none";
	if_else->add_child(*expr);
	if_else->add_child(*block);

	return if_else;
  }

  attribute *assign(attribute *attr, attribute *expr) {
    descriptor *d = sem.access_symtbl(attr->lexeme);
    int reg;
    if (d != NULL) {
      if ((d->rdest == -1)) {
        reg = reg::get_empty_reg();
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
    g_code.add("move " + string(REGISTER[assign->rdest]) + ", " + string(REGISTER[expr->rdest]) + "\n");

    if (attr->rdest != expr->rdest) {
      reg::free_temp_reg(expr->rdest);
    }

    return assign;
  }

  attribute *callout(string *callout_fn, attribute *attr) {
    attribute *syscall_setup = new attribute;
    syscall_setup->rdest = V0;
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
    g_code.add(syscall_setup->asmcode());

    attribute *callout = new attribute;
    callout->rdest = A0;
    callout->rsrc = attr->rdest;
    //cout << "CALLOUT RDEST: " << attr->lexeme << attr->rdest << endl;
    //cout << "CALLOUT RSRC: " << attr->lexeme << attr->rsrc << endl; 
    callout->opcode_type = "load";
    callout->opcode = "move";
    g_code.add(callout->asmcode());

    attribute *syscall = new attribute;
    syscall->opcode_type = "none";
    syscall->opcode = "syscall";
    syscall->add_child(*attr);
    syscall->add_child(*syscall_setup);
    syscall->add_child(*callout);

    DEBUG(syscall->print("callout"));
    g_code.add(syscall->asmcode());
    return syscall;
  }

  attribute *expr_lvalue(attribute *token) {
    descriptor *d = sem.access_symtbl(token->lexeme);
    int reg;
    
    //cout << "expr_lvalue: " << token->lexeme << token->array_index << endl;
    //cout << "register: " << d->rdest << endl;

    attribute *lvalue = new attribute;
    // If the lvalue is not an array entry
    if (token->array_index == -1) {
      if (d != NULL) {
        if ((d->rdest == -1)) {
          //cerr << "variable " << token->lexeme << " used before a value was assigned" << endl;
          //throw runtime_error("variable not in symbol table");
          d->rdest = reg::get_empty_reg();
          reg = d->rdest;
          g_code.add("lw " + string(REGISTER[d->rdest]) + ", " + d->memoryaddr + "\n");
        } else {
          reg = d->rdest;
        }
      } else {
        cerr << "variable " << token->lexeme << " used before it was defined" << endl;
        throw runtime_error("variable not in symbol table");
      }

      lvalue->opcode_type = "none";
      lvalue->rdest = reg;
      lvalue->true_list = token->true_list;
      lvalue->false_list = token->false_list;
      lvalue->next_list = token->next_list;
      lvalue->add_child(*token);
      DEBUG(lvalue->print("lvalue_expr"));
    }
    // Else the lvalue is an array entry
    else {
      reg = reg::get_temp_reg(-1, -1);
      int offset = token->array_index;
      g_code.add("mul " + string(REGISTER[offset]) + ", " + string(REGISTER[offset]) + ", 4\n");
      g_code.add("lw " + string(REGISTER[reg]) + ", " + token->lexeme + " + 0(" + string(REGISTER[offset]) + ")\n");
      reg::free_temp_reg(offset);
      lvalue->opcode_type = "none";
      lvalue->rdest = reg;

    }
    return lvalue;
  }

  attribute *binop_expr(const char *opcode, attribute *left_expr, attribute *right_expr) {
    attribute *expr = new attribute;
    expr->opcode_type = "reuse";
/*
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
*/
    expr->rdest = reg::get_temp_reg(left_expr->rdest, right_expr->rdest);
    expr->rsrc = left_expr->rdest;
    expr->rsrc2 = right_expr->rdest;
    expr->opcode = string(opcode);

    DEBUG(cerr << "left_expr: " << left_expr->asmcode());
    DEBUG(cerr << "right_expr: " << right_expr->asmcode());

    expr->add_child(*left_expr);
    expr->add_child(*right_expr);
    DEBUG(expr->print("expr"));
    g_code.add(expr->asmcode());

    if (left_expr->rdest != expr->rdest) {
      reg::free_temp_reg(left_expr->rdest);
    }
    if (right_expr->rdest != expr->rdest) {
      reg::free_temp_reg(right_expr->rdest);
    }

    return expr;
  }

  attribute *unary_expr(const char *opcode, attribute *attr) {
    attribute *unary_expr = new attribute;
/*
    if (attr->rdest == -1) {
      string attr_reg = unary_expr->first_free_register();
      unary_expr->remove_first_free_register();
      attr->result_register(attr_reg);
    }
*/
    unary_expr->rdest = reg::get_temp_reg(attr->rdest, attr->rdest);
    unary_expr->rsrc = attr->rdest;

    unary_expr->opcode_type = "load";
    unary_expr->opcode = string(opcode);
    unary_expr->add_child(*attr);
    DEBUG(unary_expr->print("unary_expr"));
    g_code.add(unary_expr->asmcode());

    if (attr->rdest != unary_expr->rdest) {
      reg::free_temp_reg(unary_expr->rdest);
    }

    return unary_expr;
  }
  
  list<int> merge_list(list<int>& l, list<int>& r){
    list<int> new_list = l;
	l.merge(r);

	return r;
  }

  string int_to_str(int i){
    stringstream out;
    out << i;
    return out.str();
  }

 
%}

%union {
  string *sval;
  attribute *attr;
  int ival;
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

%type <attr> int_field_comma_list
%type <attr> bool_field_comma_list

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

%type <ival> m

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
	g_code.print();
    //cout << sem.final(*$1) << endl;
    // $1->printtree(0);
     delete $1;
  }

program: T_CLASS class_name begin_block field_decl_list method_decl_list end_block
  {
	$$ = $5;
    //cout << "Reduce: program\n"; 
  }
     | T_CLASS class_name begin_block field_decl_list end_block
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
	$$->next_list = $3->next_list;
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
    //$$ = combine($2, $1);
  }
     | /* empty */ 
  {
    //$$ = NULL;
  }
     ;

field_decl: T_INT field int_field_comma_list T_SEMICOLON
    {
      sem.enter_symtbl($2->lexeme, *$1, -1, $2->lexeme);
      sem.access_symtbl($2->lexeme)->global = 1;
      // Address of the global variable is its name
      //$$ = field_decl($2->lexeme, $3);
      g_code.add(".globl " + $2->lexeme + "\n");
      if ($2->array_size == "") {
        g_code.add($2->lexeme + ": .word 0\n");
      }
      else {
        //cout << "It's an array" << $2->array_size << endl;
        g_code.add($2->lexeme + ": .space " + $2->array_size + "\n");
        sem.access_symtbl($2->lexeme)->array_length = atoi($2->array_size.c_str());
        //cout << "Array added to symtbl\n";
      }
    }
     | T_BOOL field bool_field_comma_list T_SEMICOLON
    {
      sem.enter_symtbl($2->lexeme, *$1, -1, $2->lexeme);
      sem.access_symtbl($2->lexeme)->global = 1;
      // Address of the global variable is its name
      //$$ = field_decl($2->lexeme, $3);
      g_code.add(".globl " + $2->lexeme + "\n");
      if ($2->array_size == "") {
        g_code.add($2->lexeme + ": .word 0\n");
      }
      else {
        g_code.add($2->lexeme + ": .space " + $2->array_size + "\n");
        sem.access_symtbl($2->lexeme)->array_length = atoi($2->array_size.c_str());
      }
    }
     | T_INT T_ID T_ASSIGN constant T_SEMICOLON
    {
      sem.enter_symtbl(*$2, *$1, -1, *$2);
      sem.access_symtbl(*$2)->global = 1;
      // Address of the global variable is its name
      g_code.add(".globl " + *$2 + "\n");
      g_code.add(*$2 + ": .word " + $4->lexeme + "\n");
    }
     | T_BOOL T_ID T_ASSIGN constant T_SEMICOLON
    {
      sem.enter_symtbl(*$2, *$1, -1, *$2);
      sem.access_symtbl(*$2)->global = 1;
      // Address of the global variable is its name
      g_code.add(".globl " + *$2 + "\n");
      g_code.add(*$2 + ": .word " + $4->lexeme + "\n");
    }
     ;

int_field_comma_list: T_COMMA field int_field_comma_list
    {
      sem.enter_symtbl($2->lexeme, string("int"), -1, $2->lexeme);
      sem.access_symtbl($2->lexeme)->global = 1;
      // Address of the global variable is its name
      //$$ = field_decl($2->lexeme, $3);
      g_code.add(".globl " + $2->lexeme + "\n");
      g_code.add($2->lexeme + ": .word 0\n");
    }
     | 
    {
      //$$ = NULL;
    }
     ;

bool_field_comma_list: T_COMMA field bool_field_comma_list
    {
      sem.enter_symtbl($2->lexeme, string("bool"), -1, $2->lexeme);
      sem.access_symtbl($2->lexeme)->global = 1;
      // Address of the global variable is its name
      //$$ = field_decl($2->lexeme, $3);
      g_code.add(".globl " + $2->lexeme + "\n");
      g_code.add($2->lexeme + ": .word 0\n");
    }
     | 
    {
      //$$ = NULL;
    }
     ;

field: T_ID
    {
      $$ = field($1);
    }
     | T_ID T_LSB T_INTCONSTANT T_RSB
    {
      $$ = field($1);
      $$->array_size = int_to_str(atoi($3->c_str()) * 4);
    }
     ;

method_decl_list: method_decl_list method_decl
	{
		$$ = combine($2, $1);
	}
     | method_decl
	{
		$$ = $1;
	}
     ;


method_decl: T_VOID T_ID 
    {
      g_code.add(*$2 + ":\n");
    }
      T_LPAREN param_list T_RPAREN block
    {
	  	$$ = $7;
    }
     | T_INT T_ID
    {
      g_code.add(*$2 + ":\n");
    }
      T_LPAREN param_list T_RPAREN block
    {
      $$ = $7;
    }
     | T_BOOL T_ID 
    {
      g_code.add(*$2 + ":\n");
    }
      T_LPAREN param_list T_RPAREN block
    {
		  $$ = $7;
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

statement_list: statement m statement_list
  {
    $$ = combine($1, $3);

	g_code.backpatch($1->next_list, $2);
	if($3 != NULL){
		$$->next_list = $3->next_list;
	}
  }
     | /* empty */ 
  {
    $$ = NULL;
  }
     ;

var_decl: T_INT T_ID int_id_comma_list T_SEMICOLON
  {
	// TODO: NO TYPE CHEKCING!!!!!!!!!!!!!!!!!
    sem.enter_symtbl(*$2, *$1, -1, "");
    $$ = var_decl($2, $3);
  }
     | T_BOOL T_ID bool_id_comma_list T_SEMICOLON
  {
	// TODO: NO TYEP CHECKING!!!!!!!!!!!!!!!!!
    sem.enter_symtbl(*$2, *$1, -1, "");
    $$ = var_decl($2, $3);
  }

int_id_comma_list: /* empty */ 
  {
    $$ = NULL;
  }
     | T_COMMA T_ID int_id_comma_list
  {
    sem.enter_symtbl(*$2, string("int"), -1, "");
    $$ = var_decl($2, $3);
  }
     ;

bool_id_comma_list: /* empty */ 
  {
    $$ = NULL;
  }
     | T_COMMA T_ID bool_id_comma_list
  {
    sem.enter_symtbl(*$2, string("bool"), -1, "");
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
     | T_IF T_LPAREN expr T_RPAREN m block n T_ELSE m block
  {
  }
     | T_IF T_LPAREN expr T_RPAREN m block 
  {
    $$ = if_else($3, $6);
	
	g_code.backpatch($3->true_list, $5);
	$$->next_list = merge_list($3->false_list, $6->next_list);
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
    //cout << "In Assign\n";
    if ($1->array_index == -1) {
      $$ = assign($1, $3);
    }
    else {
    //cout << "about to add SW\n";
    //cout << $3->rdest << endl;
    //cout << $1->lexeme << endl;
    //cout << $1->array_index << endl;
    //cout << "sw " + $3->rdest + ", " + $1->lexeme + " + 0(" + $1->array_index + ")"; 
    //cout << "added SW\n";
      g_code.add("mul " + string(REGISTER[$1->array_index]) + ", " + string(REGISTER[$1->array_index]) + ", 4\n");
      g_code.add("sw " + string(REGISTER[$3->rdest]) + ", " + $1->lexeme + " + 0(" + string(REGISTER[$1->array_index]) + ")\n"); 
      reg::free_temp_reg($1->array_index);
      reg::free_temp_reg($3->rdest);
    }
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
      | T_ID T_LSB expr T_RSB
  {
    attribute *lvalue = new attribute;
    lvalue->token = string("lvalue");
    lvalue->lexeme = *$1;
    //cout << "lvalue " << *$1 << endl;
    lvalue->array_index = $3->rdest; 
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
    //cout << "Constant: " << $1->lexeme << endl;
    $$ = constant(&($1->lexeme));
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
     | expr T_OR m expr
  {
    $$ = binop_expr("or", $1, $4);

	g_code.backpatch($1->false_list, $3);
	$$->true_list = merge_list($1->true_list, $4->true_list);
	$$->false_list = $4->false_list;
  }
     | T_MINUS expr %prec UMINUS 
  {
    $$ = unary_expr("neg", $2);
  }
     | T_NOT expr
  {
    attribute *imm = new attribute;
    imm->opcode_type = string("none");
    imm->rdest = ZERO;
    $$ = binop_expr("seq", $2, imm);
  }
     | T_LPAREN expr T_RPAREN
  {
    $$ = $2;
  }
     ;

m: { $$ = g_code.get_next_instr(); }

n: {}

constant: T_INTCONSTANT
  {
    attribute *constant = new attribute;
    constant->lexeme = *$1;
    $$ = constant;
  }
     | T_CHARCONSTANT
  {
    $$ = constant($1);
  }
     | T_TRUE
  {
    string trueval("1");
    $$ = constant(&trueval);

	$$->true_list = list<int> (1, g_code.get_next_instr());
	g_code.add(string(s_pad) + string("goto _") + string(s_newline));
  }
     | T_FALSE
  {
    string falseval("0");
    $$ = constant(&falseval);
	
	$$->false_list = list<int> (1, g_code.get_next_instr());
	g_code.add(string(s_pad) + string("goto _") + string(s_newline));
  }
     ;


%%

