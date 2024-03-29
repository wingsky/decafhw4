%{
#include "decafexpr-codegen-defs.h"
#include <iostream>
#include <stdexcept>
#include <set>

//#define _DEBUG_ON

#ifdef _DEBUG_ON
#define DEBUG(stmt) stmt;
#else
#define DEBUG(stmt) ;
#endif

  using namespace std;

  enum VAR_TYPE{
	VOID = 0,
	INT,
	BOOL,
	CHARCONSTANT,
	TYPE_COUNT
  };
  const char* TYPE_NAME[TYPE_COUNT] = {"void", "int", "bool", "char constant"};
  const char* INTEGER_OP[] = {"+","-","*","/","<<",">>","rot","%","<",">","<=",">=", "rot"};
  const char* BOOL_OP[] = {"&&", "||", "!"};
  const char* BOOL_RETURN_OP[] = {"==", "!=", "<", ">", "<=", ">=", "&&", "||", "!"};
  set<const char*> integer_op_set(INTEGER_OP, INTEGER_OP + sizeof(INTEGER_OP)/sizeof(char*));
  set<const char*> bool_op_set(BOOL_OP, BOOL_OP + sizeof(BOOL_OP)/sizeof(char*));
  set<const char*> bool_return_op_set(BOOL_RETURN_OP, BOOL_RETURN_OP + sizeof(BOOL_RETURN_OP)/sizeof(char*));

  semantics sem;
  code g_code;
  string block_owner = "";
  int tmp_pos; 
  long global_size = 0;
  long heap_offset = 0; 
  bool param_set = 0; 
  list<int> sp_diff;
  
  string int_to_str(int);

  list<int> merge_list(list<int>& l, list<int>& r){
    list<int> new_list = l;
	new_list.merge(r);

	return new_list;
  }

  void err(string err_msg, string err_type){
	cerr << "Line: " << lineno << " - "<< err_msg;
    throw runtime_error(err_type.c_str());
  }

  

  attribute *constant(string *immvalue, int type) {
    attribute *attr = new attribute;
    attr->token = string("constant");
    attr->lexeme = *immvalue;
    attr->imm = *immvalue;
	attr->type = type;
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
	  parent->sp_diff = attr->sp_diff + attrlist->sp_diff;
      parent->add_child(*attr);
      parent->add_child(*attrlist);
	  //parent->next_list = merge_list(attr->next_list, attrlist->next_list);
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

  attribute* while_stmt(attribute *expr, attribute* block){
	attribute *while_stmt= new attribute;
	while_stmt->token = string("while");
	while_stmt->opcode_type = "none";
	while_stmt->sp_diff = block->sp_diff;
	while_stmt->add_child(*expr);
	while_stmt->add_child(*block);

  reg::free_temp_reg(expr->rdest);
	return while_stmt;
  }

  attribute* for_stmt(attribute* assign_comma_list1, attribute* expr, attribute* assign_comma_list2, attribute* block){
    attribute* for_stmt = new attribute;
	for_stmt->token = string("for");
	for_stmt->opcode_type = "none";
	for_stmt->sp_diff += block->sp_diff;
	for_stmt->add_child(*assign_comma_list1);
	for_stmt->add_child(*expr);
	for_stmt->add_child(*assign_comma_list2);
	for_stmt->add_child(*block);

  //reg::free_temp_reg(expr->rdest);
	return for_stmt;
  }

  attribute *if_else(attribute *expr, attribute *block){
	attribute *if_else = new attribute;
	if_else->token = string("if");
	if_else->opcode_type = "none";
	if_else->sp_diff = block->sp_diff;
	if_else->add_child(*expr);
	if_else->add_child(*block);
  
  //reg::free_temp_reg(expr->rdest);
	return if_else;
  }
  
  attribute *if_else(attribute *expr, attribute *block1, attribute *block2){
	attribute *if_else = new attribute;
	if_else->token = string("if_else");
	if_else->opcode_type = "none";
	if_else->sp_diff =  block1->sp_diff + block2->sp_diff;
	if_else->add_child(*expr);
	if_else->add_child(*block1);
	if_else->add_child(*block2);

  reg::free_temp_reg(expr->rdest);
	return if_else;
  }

  attribute *assign(attribute *attr, attribute *expr) {

    descriptor *d = sem.access_symtbl(attr->lexeme);
    int spill = 0;
    int reg = -1;
    int offset;

	if(d->type != expr->type){
		string err_msg = string("type mismatch between when assign value to variable '") + attr->lexeme + string("'\n");
		string err_type = string("type mismatch");
		err(err_msg, err_type);
	}
    if (d != NULL) {
      if ((d->rdest == -1)) {
        if( d->offset == 0) {
          reg = reg::get_empty_reg(attr->lexeme);
        }
        if (reg == -1) {
          // Allocate a temp reg, and spill it to memory
          //reg = reg::get_temp_reg(expr->rdest, expr->rdest);
          d->rdest = -1;
          spill = 1;
          //cout << "use spilled " << attr->lexeme << endl;
        } else {
          // Allocate a s reg
          d->rdest = reg;
        }
      } else {
        reg = d->rdest;
      }
    } else {
	  string err_msg = string("variable ") + attr->lexeme + string(" used before it was defined\n");
	  string err_type = string("variable not in symbol table");
	  err(err_msg, err_type);
    }

    attribute *assign = new attribute;
    assign->opcode_type = "load";
    assign->opcode = "move";
    assign->rdest = reg;
    assign->rsrc = expr->rdest;
    assign->add_child(*attr);
    assign->add_child(*expr);
    DEBUG(assign->print("assign"));
    if (spill == 0) {
      g_code.add(" move " + string(REGISTER[assign->rdest]) + ", " + string(REGISTER[expr->rdest]) + "\n");
    } 
    // If spill, write reg to memory and decrement stack pointer
    else if (spill == 1) {
        int offset;
        if (d->offset != 0) {
          //cout << d->name << " has offset " << offset << endl;
          offset = d->offset;
          g_code.add(" sw " + string(REGISTER[expr->rdest]) + ", " + int_to_str(offset) + "($fp)  #spill to stack\n" );
        } else {
          //cerr << d->name << " spilling to stack " << endl;
          //cerr << block_owner << "stack size " << sem.mtdtbl[block_owner]->stack_size << endl;
          offset = -(sem.mtdtbl[block_owner]->stack_size);
          sem.mtdtbl[block_owner]->stack_size += 4;
          sp_diff.back() += 4;
          g_code.add(" sw " + string(REGISTER[expr->rdest]) + ", " + int_to_str(offset) + "($fp)  #spill to stack\n" );
          g_code.add(" addiu $sp, $sp, -4\n");
          d->rdest = -1;
          d->offset = offset;
        }
        
    }

    if (attr->rdest != expr->rdest) {
      reg::free_temp_reg(expr->rdest);
    }

    return assign;
  }

  attribute *callout(string *callout_fn, attribute *attr) {
	attribute *syscall_setup = new attribute;
    syscall_setup->rdest = V0;
    syscall_setup->imm = "_ERROR_";

    if (*callout_fn == "\"print_int\""){
      syscall_setup->imm = "1";
	  if(attr == NULL){
		string err_msg =  string("callout function ") + *callout_fn + string(" should have a second argument!\n");
		string err_type("callout function missing argument");
		err(err_msg, err_type);
	  }else if(attr->token == "stringconst"){
		string err_msg = string("callout function ") + *callout_fn + string("'s second argument cannot be string constant!'\n");
		string err_type("callout function wrong argument type");
		err(err_msg, err_type);
	  }

	} else if (*callout_fn == "\"read_int\""){
      syscall_setup->imm = "5";
	  if(attr != NULL){
		string err_msg = string("callout \"read_int\" only accepts one argument\n");
		string err_type = string("callout function wrong argument type");

		err(err_msg, err_type);
	  }
	} else if (*callout_fn == "\"print_string\""){
      syscall_setup->imm = "4";
	  if(attr == NULL){
		string err_msg = string("callout function ") + *callout_fn + string(" should have a second argument!\n");
		string err_type = string("callout function missing argument");

		err(err_msg, err_type);
	  } else if(attr->token != "stringconst"){
		string err_msg = string("callout function ") + *callout_fn + string("'s second argument must be string constant!'\n");
		string err_type("callout function wrong argument type");

		err(err_msg, err_type);
	  }
	}

    if (syscall_setup->imm == "_ERROR_") {
      string err_msg = string("callout function ") + *callout_fn + string(" is not supported\n");
      string err_type("callout function not supported");

	  err(err_msg, err_type);
    }


    syscall_setup->opcode_type = "imm";
    syscall_setup->opcode = "li";
    g_code.add(syscall_setup->asmcode());

	attribute* callout = NULL;
	if(*callout_fn == "\"print_int\""){
		callout = new attribute;
		callout->rdest = A0;
		callout->rsrc = attr->rdest;
		//cout << "CALLOUT RDEST: " << attr->lexeme << attr->rdest << endl;
		//cout << "CALLOUT RSRC: " << attr->lexeme << attr->rsrc << endl; 
		callout->opcode_type = "load";
		callout->opcode = "move";
		g_code.add(callout->asmcode());

    if ((attr->rdest < T9) && (attr->rdest > T0)) {
      reg::free_temp_reg(attr->rdest);
    }

	} else if(*callout_fn == "\"print_string\""){
		//callout = new attribute;
		g_code.add(" la " + string(REGISTER[A0]) + ", " + attr->lexeme + string("\n"));
	}

    attribute *syscall = new attribute;
    syscall->opcode_type = "none";
    syscall->opcode = "syscall";
	if(*callout_fn == "\"read_int\""){
		syscall->rdest = V0;
		syscall->type = INT;
	}
    syscall->add_child(*syscall_setup);
    if(callout != NULL){
		syscall->add_child(*attr);
		syscall->add_child(*callout);
	}

    DEBUG(syscall->print("callout"));
    g_code.add(syscall->asmcode());
    return syscall;
  }

  attribute *expr_lvalue(attribute *token) {
    descriptor *d = sem.access_symtbl(token->lexeme);
    int reg;
	int type;
	
	if(d == NULL){
		string err_msg = string("variable ") + token->lexeme + string(" used before it was defined\n");
        string err_type("variable not in symbol table");

		err(err_msg, err_type);
	}
   
    attribute *lvalue = new attribute;
	
	lvalue->type = d->type;
	lvalue->lexeme = token->lexeme;
    //cout << "expr_lvalue: " << token->lexeme << token->array_index << endl;
    //cout << "register: " << d->rdest << endl;

    // If the lvalue is not an array entry
    if (token->array_index == -1) {
        // If it is not in an register (global var or spilled local var)
  
      if ((d->rdest == -1)) {
        //cerr << "variable " << token->lexeme << " used before a value was assigned" << endl;
        //throw runtime_error("variable not in symbol table");
        //cerr << "l expr " << d->name << " not in reg\n";
        if (d->global) {
          // It is a global var
          d->rdest = reg::get_temp_reg(-1, -1);
          reg = d->rdest;
          g_code.add(" lw " + string(REGISTER[d->rdest]) + ", " + d->memoryaddr + "\n");
        } else {
          //cerr << "get l expr from mem " << d->name << endl;
          // It is a spilled local var
          reg = reg::get_temp_reg(-1, -1);
          //d->rdest = reg;
          g_code.add(" lw " + string(REGISTER[reg]) + ", " + int_to_str(d->offset) + "($fp)  # load from stack\n");
        }
      } else {
        reg = d->rdest;
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
      g_code.add(" mul " + string(REGISTER[offset]) + ", " + string(REGISTER[offset]) + ", 4\n");
      g_code.add(" lw " + string(REGISTER[reg]) + ", " + token->lexeme + " + 0(" + string(REGISTER[offset]) + ")  # load array from mem\n");
      reg::free_temp_reg(offset);
      lvalue->opcode_type = "none";
      lvalue->rdest = reg;
      reg::free_temp_reg(offset);
    }
    return lvalue;
  }

attribute *binop_expr(const char *opcode, const char* op, attribute *left_expr, attribute *right_expr) {
   //cout << "(" << left_expr->type << "  "<<left_expr->lexeme << ") ";
   //cout << op;
   //cout << " (" << right_expr->type << "  "<<right_expr->lexeme << ")\n";
	if(left_expr->type != right_expr->type){
		if(string(op) != "!"){
			string err_msg = string("type mismatch between ") + left_expr->lexeme + string(" and ") + right_expr->lexeme + string("\n");
			string err_type("type mismatch");

			err(err_msg, err_type);
		}
	}
	if(integer_op_set.find(op) != integer_op_set.end()){
		if(left_expr->type != INT || right_expr->type != INT){
			string err_msg = string("operator ") + op + string(" only accepts int type\n");
			string err_type("operator type error");

			err(err_msg, err_type);
		}
	}
	if(bool_op_set.find(op) != bool_op_set.end()){
		if(left_expr->type != BOOL || right_expr->type != BOOL){
			string err_msg = string("operator ") + op + string(" only accepts bool type\n");
			string err_type("operator type error");

			err(err_msg, err_type);
		}
	}
    
	attribute *expr = new attribute;

	if(bool_return_op_set.find(op) != bool_return_op_set.end()){
		expr->type = BOOL;
	} else{
		expr->type = INT;
	}
	//cout << "result type: " << expr->type << endl;
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
	  if (string(opcode) != "rot") {
      g_code.add(expr->asmcode());
    }
    else {
      
    }
    if (left_expr->rdest != expr->rdest) {
      reg::free_temp_reg(left_expr->rdest);
    }
    if (right_expr->rdest != expr->rdest) {
      reg::free_temp_reg(right_expr->rdest);
    }

    return expr;
}

attribute *unary_expr(const char *opcode, const char* op, attribute *attr) {
    attribute *unary_expr = new attribute;
/*
    if (attr->rdest == -1) {
      string attr_reg = unary_expr->first_free_register();
      unary_expr->remove_first_free_register();
      attr->result_register(attr_reg);
    }
*/
	if(attr->type != INT){
		string err_msg = "operator " + string(op) + " only accepts int type\n";
		string err_type = "operator type error";

		err(err_msg, err_type);
	}
	unary_expr->type = attr->type;
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

  
  

string int_to_str(int i){
	stringstream out;
	out << i;
	return out.str();
}

string* next_label(){
	static int label_num = 0;
	string* s = new string;
	*s += string("$L") + int_to_str(++label_num);

	string label = *s + string(":") + s_newline;
	g_code.add(label);


	return s;
}

int next_instr(string s){
	int retval = g_code.get_next_instr();
	g_code.add(s);
	
	return retval;
}

string callee_save(method_descriptor *d) {
      
      string tmp_s = "";
      int var_count = d->var_count;
      int arg_count = d->args.size();
      d->stack_size = (18 + 2 + arg_count) * 4; // $t + $s + $ra + $fp + arguments
      d->original_stack_size = d->stack_size;
      if ((d->stack_size % 8) != 0) {
        d->stack_size = d->stack_size + 4;
      }
      
      tmp_s += " subu $sp, $sp, " + int_to_str(d->stack_size) + "\n";
      tmp_s += " sw $ra, " + int_to_str(d->stack_size - 4) + "($sp)\n";
      tmp_s += " sw $fp, " + int_to_str(d->stack_size - 8) + "($sp)\n";
      // Set its $fp
      tmp_s += " addiu $fp, $sp, " + int_to_str(d->stack_size - 4) + "\n";

      d->hi_ptr = -8;
      d->lo_ptr = -(d->stack_size - 4);

      for (int i = S0; i <= S7; i++) {
        // Save to stack if s is not empty
        //if ( !regtbl[i].empty()) {
          tmp_s += " sw " + string(REGISTER[i]) + ", " + int_to_str(d->lo_ptr) + "($fp)  # callee save\n";  
          d->saved_regs.push_back(i);
          d->lo_ptr = d->lo_ptr + 4;
          regtbl[i].clear();
        //}
      }
      //cout << d->method_id << " " << d->lo_ptr << endl;
      d->lo_ptr = d->lo_ptr - 4;
      
      // Put arguments into registers
      vector< pair<string, int> >::reverse_iterator it;
      int s_reg;
      for( it = d->args.rbegin(); it != d->args.rend(); it++) {
        s_reg = reg::get_empty_reg((*it).first);
        //cout << "load argu " << (*it).first << endl;
        //cout << "into " << REGISTER[s_reg] << endl;
        tmp_s += " lw " + string(REGISTER[s_reg]) + ", " + int_to_str(d->hi_ptr) + "($fp)  # load argument " + (*it).first + "\n";
        sem.access_symtbl((*it).first)->rdest = s_reg; 
        d->hi_ptr = d->hi_ptr - 4;

      }
        d->hi_ptr = d->hi_ptr + 4;
      return tmp_s;
}
 
  string callee_restore(method_descriptor *d) {
    
    string tmp_s = "";
    // Put return value in $v0
    if (d->return_type != VOID) {
      
    }
    // Restore callee-saved registers
    // Restore $s0-$s7
    vector<int>::reverse_iterator it;
    //d->lo_ptr -= 4; 
    for (it = d->saved_regs.rbegin(); it != d->saved_regs.rend(); it++) {
       tmp_s += " lw " + string(REGISTER[*it]) + ", " + int_to_str(d->lo_ptr) + "($fp)  # callee restore\n";
       d->lo_ptr = d->lo_ptr - 4;
    }
    d->lo_ptr += 4;
    d->saved_regs.clear();

    tmp_s+= " addiu $sp, $fp, 4\n";
    tmp_s+= " lw $ra, 0($fp)\n";
    tmp_s+= " lw $fp, -4($fp)\n";
    tmp_s+= " jr $ra\n";

    return tmp_s;
  }

  string caller_save(method_descriptor *caller, string callee_id) {

    string tmp_s = "";
    // Pass arguments
    caller->lo_ptr += 4;
    for (int i = T0; i <= T9; i++) {
      // Save if non-empty
      //if ( !regtbl[i].empty()) {
        tmp_s += " sw " + string(REGISTER[i]) + ", " + int_to_str(caller->lo_ptr) + "($fp)  # caller save\n";
        caller->saved_tmp.push_back(i);
        caller->lo_ptr = caller->lo_ptr + 4;
      //}
    }
    caller->lo_ptr = caller->lo_ptr - 4;
    // jal to function
    return tmp_s;
  }

  string caller_restore(method_descriptor *caller) {
    string tmp_s = "";
    vector<int>::reverse_iterator it;
    for (it = caller->saved_tmp.rbegin(); it != caller->saved_tmp.rend(); it++) {
      tmp_s += " lw " + string(REGISTER[*it]) + ", " + int_to_str(caller->lo_ptr) + "($fp)  # caller restore\n";
      caller->lo_ptr = caller->lo_ptr - 4;
    }
    //caller->lo_ptr += 4;
    caller->saved_tmp.clear();
    return tmp_s;
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
%type <attr> var_decl
%type <attr> var_decl_list
%type <attr> start

%type <sval> generate_label
%type <ival> jal
%type <ival> begin_if_stmt
%type <ival> end_if_stmt

%type <sval> begin_expr
%type <ival> end_expr

%type <attr> if_expr

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
    //g_code.add(" jr $ra\n");
    
    /*
    for (int i = 0; i < sem.mtdtbl[string("foo")]->args.size(); i++) {
      cout << sem.mtdtbl[string("foo")]->args[i] << endl;
    }
    */
    //cout << sem.final(*$1) << endl;
    // $1->printtree(0);
	//if(!($1->next_list.empty())){
	//	g_code.backpatch($1->next_list, next_label());
	//}	
	delete $1;
  
  // Check if the program has a main() method
  if (sem.mtdtbl["main"] == NULL) {
    string err_msg = "no main() method in this program\n";
    string err_type = "no main() method error";
    err(err_msg, err_msg);

  }

	g_code.print();

  //cout << "GLOBAL SIZE: " << global_size << endl;
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

block: begin_block var_decl_list 
  {
  }
       statement_list end_block
  {
    
    delete $2;
    $$ = $4;
    //$$->sp_diff = 0;
    if ($5 != NULL) {
      $$->roll_back_label = $5->roll_back_label;
      $$->sp_diff +=  $5->sp_diff;
      delete $5;
    }
  }

begin_block: T_LCB
  {
    if (param_set == 0) {
      sem.new_symtbl();
    }
    else {
      param_set = 0;
    }
    sp_diff.push_back(0);
  }

end_block: T_RCB
  {
    attribute *end_block = NULL;
    sem.remove_symtbl();
    //cout << sp_diff.back() << endl;
    if (sp_diff.back() != 0) {
      string *label = next_label();
      g_code.add(" addiu $sp, $sp, " + int_to_str(+sp_diff.back()) + "  # roll back $sp\n");
      //cout << "roll back\n";
      //cout << "current stack size " << sem.mtdtbl[block_owner]->stack_size << endl; 
      end_block = new attribute;
      end_block->roll_back_label = *label;
      end_block->sp_diff = sp_diff.back();
      delete label;
    }
    $$ = end_block;
    sp_diff.pop_back();
  }

field_decl_list: field_decl_list field_decl
  {
  }
     | /* empty */ 
  {
  }
     ;

field_decl: T_INT field int_field_comma_list T_SEMICOLON
    {
      sem.enter_symtbl($2->lexeme, INT, -1, $2->lexeme, lineno);
      sem.access_symtbl($2->lexeme)->global = 1;
      // Address of the global variable is its name
      //$$ = field_decl($2->lexeme, $3);
      g_code.global_decl.push_back(".globl " + $2->lexeme + "\n");
      if ($2->array_size == "") {
        g_code.global_decl.push_back($2->lexeme + ": .word 0\n");
      }
      else {
        //cout << "It's an array" << $2->array_size << endl;
        g_code.global_decl.push_back($2->lexeme + ": .word 0:" + $2->array_size + "\n");
        sem.access_symtbl($2->lexeme)->array_length = atoi($2->array_size.c_str());
        //cout << "Array added to symtbl\n";
      }
    }
     | T_BOOL field bool_field_comma_list T_SEMICOLON
    {
      sem.enter_symtbl($2->lexeme, BOOL, -1, $2->lexeme, lineno);
      sem.access_symtbl($2->lexeme)->global = 1;
      // Address of the global variable is its name
      //$$ = field_decl($2->lexeme, $3);
      g_code.global_decl.push_back(".globl " + $2->lexeme + "\n");
      if ($2->array_size == "") {
        g_code.global_decl.push_back($2->lexeme + ": .word 0\n");
      }
      else {
        g_code.global_decl.push_back($2->lexeme + ": .word 0:" + $2->array_size + "\n");
        sem.access_symtbl($2->lexeme)->array_length = atoi($2->array_size.c_str());
      }
    }
     | T_INT T_ID T_ASSIGN constant T_SEMICOLON
    {
      sem.enter_symtbl(*$2, INT, -1, *$2, lineno);
      sem.access_symtbl(*$2)->global = 1;
      // Address of the global variable is its name
      g_code.global_decl.push_back(".globl " + *$2 + "\n");
      g_code.global_decl.push_back(*$2 + ": .word " + $4->lexeme + "\n");
      global_size += 4;
    }
     | T_BOOL T_ID T_ASSIGN constant T_SEMICOLON
    {
      sem.enter_symtbl(*$2, BOOL, -1, *$2, lineno);
      sem.access_symtbl(*$2)->global = 1;
      // Address of the global variable is its name
      g_code.global_decl.push_back(".globl " + *$2 + "\n");
      g_code.global_decl.push_back(*$2 + ": .word " + $4->lexeme + "\n");
      global_size += 4;
    }
     ;

int_field_comma_list: T_COMMA field int_field_comma_list
    {
      sem.enter_symtbl($2->lexeme, INT, -1, $2->lexeme, lineno);
      sem.access_symtbl($2->lexeme)->global = 1;
      // Address of the global variable is its name
      //$$ = field_decl($2->lexeme, $3);
      g_code.global_decl.push_back(".globl " + $2->lexeme + "\n");
      g_code.global_decl.push_back($2->lexeme + ": .word 0\n");
    }
     | 
    {
    }
     ;

bool_field_comma_list: T_COMMA field bool_field_comma_list
    {
      sem.enter_symtbl($2->lexeme, BOOL, -1, $2->lexeme, lineno);
      sem.access_symtbl($2->lexeme)->global = 1;
      // Address of the global variable is its name
      //$$ = field_decl($2->lexeme, $3);
      g_code.global_decl.push_back(".globl " + $2->lexeme + "\n");
      g_code.global_decl.push_back($2->lexeme + ": .word 0\n");
    }
     | 
    {
      //$$ = NULL;
    }
     ;

field: T_ID
    {
      $$ = field($1);
      global_size += 4;
    }
     | T_ID T_LSB T_INTCONSTANT T_RSB
    {
      global_size += atoi($3->c_str()) * 4;
      $$ = field($1);
      $$->array_size = int_to_str(global_size / 4);
       
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
      T_LPAREN param_list T_RPAREN 
    {  
      sem.enter_method(*$2, VOID, $5->arglist);
      delete $5;
      block_owner = *$2;
      tmp_pos = g_code.get_next_instr();

      // symtbl in middle layers
      sem.new_symtbl();
      param_set = 1; 

      method_descriptor *d = sem.mtdtbl[*$2];
      vector< pair<string, int> >::iterator it;
      for (it = d->args.begin(); it != d->args.end(); it++) {
         // Put parameter name into symbol table
         sem.enter_symtbl((*it).first, (*it).second, -1, "", lineno); 
         //  cout << "PARAM TYPE: " << (*it).first << " " << (*it).second << endl;
      }

      string tmp_s = callee_save(sem.mtdtbl[*$2]);
      g_code.add(tmp_s);
    }  
      block
    {
      string tmp_s = callee_restore(sem.mtdtbl[*$2]);
      string return_label = block_owner + "_return";
      g_code.add(return_label + ":\n");
      g_code.add(tmp_s);
      $$ = $8;
      //cout << block_owner << " " << sem.mtdtbl[block_owner]->var_count << endl;
      if(!($8->next_list.empty())){
			  g_code.backpatch($8->next_list, &(return_label));
	  	}
      block_owner = "";

    }
     | T_INT T_ID
    {
      g_code.add(*$2 + ":\n");
    }
      T_LPAREN param_list T_RPAREN 
    {  
      sem.enter_method(*$2, INT, $5->arglist);
      delete $5;
      block_owner = *$2;
      tmp_pos = g_code.get_next_instr();

      // symtbl in middle layer
      sem.new_symtbl();
      param_set = 1;

      method_descriptor *d = sem.mtdtbl[*$2];
      vector< pair<string, int> >::iterator it;
      for (it = d->args.begin(); it != d->args.end(); it++) {
         // Put parameter name into symbol table
        sem.enter_symtbl((*it).first, (*it).second, -1, "", lineno); 
       // cout << "PARAM TYPE: " << (*it).first << " " << (*it).second << endl;
      }

      string tmp_s = callee_save(sem.mtdtbl[*$2]);
      g_code.add(tmp_s);
    }  
      block
    {
      string tmp_s = callee_restore(sem.mtdtbl[*$2]);
      string return_label = block_owner + "_return";
      g_code.add(return_label + ":\n");
      g_code.add(tmp_s);
      $$ = $8;
      //cout << block_owner << " " << sem.mtdtbl[block_owner]->var_count << endl;
      if(!($8->next_list.empty())){
			  g_code.backpatch($8->next_list, &(return_label));
	  	}
      block_owner = "";

    }
     | T_BOOL T_ID 
    {
      g_code.add(*$2 + ":\n");
    }
      T_LPAREN param_list T_RPAREN 
    {
      sem.enter_method(*$2, BOOL, $5->arglist);
      delete $5;
      block_owner = *$2;
      tmp_pos = g_code.get_next_instr();

      // symtbl in middle layer
      sem.new_symtbl();
      param_set = 1;

      method_descriptor *d = sem.mtdtbl[*$2];
      vector< pair<string, int> >::iterator it;
      for (it = d->args.begin(); it != d->args.end(); it++) {
         // Put parameter name into symbol table
         sem.enter_symtbl((*it).first, (*it).second, -1, "", lineno); 
       // cout << "PARAM TYPE: " << (*it).first << " " << (*it).second << endl;
      }

      
      string tmp_s = callee_save(sem.mtdtbl[*$2]);
      g_code.add(tmp_s);
    }
      block
    {
      string tmp_s = callee_restore(sem.mtdtbl[*$2]);
      string return_label = block_owner + "_return";
      g_code.add(return_label + ":\n");
      g_code.add(tmp_s);
      $$ = $8;
      //cout << block_owner << " " << sem.mtdtbl[block_owner]->var_count << endl;
      if(!($8->next_list.empty())){
			  g_code.backpatch($8->next_list, &(return_label));
	  	}
      block_owner = "";

    }
     ;

param_list: param_comma_list
  {
    $$ = $1; 
/*
    vector< pair<string, int> >::iterator it;
    cout << "param enter order: \n";
    for (it = $$->arglist.begin(); it != $$->arglist.end(); it++) {
       // Put parameter name into symbol table
       cout << (*it).first << " " << (*it).second << endl; 
     // cout << "PARAM TYPE: " << (*it).first << " " << (*it).second << endl;
    }
*/
  }
     | /* empty */
  {
    attribute *pcl = new attribute;
    $$ = pcl;
  }
     ;

param_comma_list: param T_COMMA param_comma_list
  {
    $$ = $3; 
    $3->arglist.push_back(pair<string, int>($1->lexeme, $1->type));
    delete $1;
  }
     | param
  {
    attribute *pcl = new attribute;
    pcl->arglist.push_back(pair<string, int>($1->lexeme, $1->type));
    delete $1;
    $$ = pcl;
  }
     ;

param: T_INT T_ID
  {
    attribute *param = new attribute;
    param->type = INT;
    param->lexeme = *$2;
    $$ = param;
    
  }
     | T_BOOL T_ID
  {
    attribute *param = new attribute;
    param->type = BOOL;
    param->lexeme = *$2;
    $$ = param;
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

statement_list: statement_list 
  {
	if(!($1->next_list.empty())){ 
	  string* label = next_label();
	  g_code.backpatch($1->next_list, label);
	  delete label;
	  if($1->sp_diff != 0){
	    g_code.add(string(" addiu ") + string(" $sp, $sp, ") + int_to_str(-($1->sp_diff)) + string(" #unroll $sp\n"));			
		$1->sp_diff = 0;
	  }
	}
  }		
	   statement
  {
    $$ = combine($3, $1);
	$$->break_list = merge_list($1->break_list, $3->break_list);
	$$->continue_list = merge_list($1->continue_list, $3->continue_list);
	$$->next_list = $3->next_list;
  }
     | statement 
  {
	$$ = $1;
  }
     ;

var_decl: T_INT T_ID int_id_comma_list T_SEMICOLON
  {
	// TODO: NO TYPE CHEKCING!!!!!!!!!!!!!!!!!
    sem.enter_symtbl(*$2, INT, -1, "", lineno);
    $$ = var_decl($2, $3);
    if (block_owner == "") {
      cout << "ERROR: empty block_owner\n";
    }
    sem.mtdtbl[block_owner]->var_count++;
  }
     | T_BOOL T_ID bool_id_comma_list T_SEMICOLON
  {
	// TODO: NO TYEP CHECKING!!!!!!!!!!!!!!!!!
    sem.enter_symtbl(*$2, BOOL, -1, "", lineno);
    $$ = var_decl($2, $3);
    if (block_owner == "") {
      cout << "ERROR: empty block_owner\n";
    }
    sem.mtdtbl[block_owner]->var_count++;
  }

int_id_comma_list: /* empty */ 
  {
    $$ = NULL;
  }
     | T_COMMA T_ID int_id_comma_list
  {
    sem.enter_symtbl(*$2, INT, -1, "", lineno);
    $$ = var_decl($2, $3);
    sem.mtdtbl[block_owner]->var_count++;
  }
     ;

bool_id_comma_list: /* empty */ 
  {
    $$ = NULL;
  }
     | T_COMMA T_ID bool_id_comma_list
  {
    sem.enter_symtbl(*$2, BOOL, -1, "", lineno);
    $$ = var_decl($2, $3);
    sem.mtdtbl[block_owner]->var_count++;
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
     | T_IF T_LPAREN if_expr T_RPAREN begin_if_stmt block end_if_stmt T_ELSE generate_label block
  {
	$$ = if_else($3, $6, $10);

	g_code.get($5) = string(" beq ") + REGISTER[$3->rdest] + string(" $zero ") + *$9 + string("\n");
	$6->next_list.push_back($7);
	$$->next_list = merge_list($6->next_list, $10->next_list);
	$$->break_list = merge_list($6->break_list, $10->break_list);
	$$->continue_list = merge_list($6->continue_list, $10->continue_list);
	delete $9;
  }
     | T_IF T_LPAREN if_expr T_RPAREN begin_if_stmt block 
  {
    $$ = if_else($3, $6);

	g_code.get($5) = string(" beq ") + REGISTER[$3->rdest] + string(" $zero _\n");
	$3->false_list.push_back($5);
	$$->next_list = merge_list($3->false_list, $6->next_list);
	$$->break_list.merge($6->break_list);
	$$->continue_list.merge($6->continue_list);
  }
     | T_WHILE begin_expr T_LPAREN expr {reg::free_temp_reg($4->rdest);} T_RPAREN end_expr block
  {
	$$ = while_stmt($4, $8);

	g_code.get($7) = string(" beq ") + REGISTER[$4->rdest] + string(" $zero _\n");
	if($8->roll_back_label != ""){
		g_code.backpatch($8->next_list, &($8->roll_back_label));
		g_code.backpatch($8->continue_list, &($8->roll_back_label));
	} else{
		g_code.backpatch($8->next_list, $2);
		g_code.backpatch($8->continue_list, $2);
	}
	$$->next_list.push_back($7);
	$$->next_list.merge($8->break_list);
	g_code.add(string(" j ") + *$2 + string("\n"));
	delete $2;
  }
     | T_FOR T_LPAREN assign_comma_list T_SEMICOLON begin_expr expr 
  {
	reg::free_temp_reg($6->rdest);
  }	   
       end_expr jal T_SEMICOLON generate_label assign_comma_list jal T_RPAREN generate_label block
  {
	$$ = for_stmt($3, $6, $12, $16);
	
	g_code.get($8) = string(" beq ") + REGISTER[$6->rdest] + string(" $zero _\n");
	g_code.get($9) = string(" j ") + *$15 + string("\n");
	g_code.get($13) = string(" j ") + *$5 + string("\n");
	$16->next_list.merge($16->continue_list);
	if($16->roll_back_label != ""){
		g_code.backpatch($16->next_list, &($16->roll_back_label));
	}else{
		g_code.backpatch($16->next_list, $11);
	}
	$$->next_list.push_back($8);
	$$->next_list.merge($16->break_list);
	g_code.add(string(" j ") + *$11 + string("\n"));
	delete $15, $5, $11;
  }
     | T_RETURN opt_expr T_SEMICOLON
  {
    if ($2->rdest != -1) {
      // Check if method return type matches the expr being returned
      if ($2->type != sem.mtdtbl[block_owner]->return_type) {
         string err_msg = string("method ") + block_owner + string(" requires return type ") + TYPE_NAME[sem.mtdtbl[block_owner]->return_type] + string("\n");
         string err_type("return type error");

         err(err_msg, err_type);
      }
      g_code.add(" move $v0, " + string(REGISTER[$2->rdest]) + "  # move return value into $v0\n");
    }
      g_code.add(" j " + block_owner + "_return  #jump to callee_restore\n");
      delete $2;
    attribute *return_stmt = new attribute;
    $$ = return_stmt;
  }
     | T_BREAK T_SEMICOLON
  {
	attribute* break_stmt = new attribute;

	break_stmt->break_list.push_back(next_instr(string(" j _\n")));
	$$ = break_stmt;
  }
     | T_CONTINUE T_SEMICOLON
  {
	attribute* continue_stmt = new attribute;

	continue_stmt->continue_list.push_back(next_instr(string(" j _\n")));
	$$ = continue_stmt;
  }
     | block
  {
    $$ = $1;
  }
     ;

if_expr: expr
  {
	$$ = $1;
	reg::free_temp_reg($1->rdest);
  }
	;

begin_expr: 
  {
	$$ = next_label();
  }
     ;

end_expr: 
  {
	$$ = next_instr(string("\n"));
  }
	 ;

begin_if_stmt: 
  { 
	$$ = next_instr(string("\n"));
  }
	;
end_if_stmt:
  {
	$$ = next_instr(string(" j _\n"));
  }

jal:
  {
	$$ = next_instr(string(" j _\n"));
  }

generate_label: 
  { 
	$$ = next_label();
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
      g_code.add(" mul " + string(REGISTER[$1->array_index]) + ", " + string(REGISTER[$1->array_index]) + ", 4\n");
      g_code.add(" sw " + string(REGISTER[$3->rdest]) + ", " + $1->lexeme + " + 0(" + string(REGISTER[$1->array_index]) + ")\n"); 
      reg::free_temp_reg($1->array_index);
      reg::free_temp_reg($3->rdest);
    }
  }

method_call: T_ID 
  {
    tmp_pos = -(sem.mtdtbl[block_owner]->stack_size + 8); 
    //cout << block_owner << "stack size " << tmp_pos << endl;
  }
              T_LPAREN expr_comma_list T_RPAREN
  {	
    attribute *method_call = new attribute;
    //cout << "start get rtype\n";
    method_call->type = sem.mtdtbl[*$1]->return_type;
    //cout << "end get rtype\n";
    $$ = method_call;
    string tmp_s = "";
    //cout << "caller_save\n";

    tmp_s = caller_save(sem.mtdtbl[block_owner], *$1);  
    g_code.add(tmp_s);
     
    // Put arguments on callee's stack
    g_code.add($4->mipsCode); 
    g_code.add(" jal " + *$1 + "\n");
    tmp_s = caller_restore(sem.mtdtbl[block_owner]);
    delete $4;
    g_code.add(tmp_s);
  }
           | T_CALLOUT T_LPAREN T_STRINGCONSTANT callout_arg_comma_list T_RPAREN
  {
    $$ = callout($3, $4);
  };

expr_comma_list: opt_expr
  {
    $$ = $1;
  }
     | expr 
  {
     
    attribute *expr = new attribute;
    expr->mipsCode = " sw " + string(REGISTER[$1->rdest]) + ", " + int_to_str(tmp_pos) + "($fp)  #pass argument\n"; 
    $1 = expr;
    tmp_pos = tmp_pos - 4;
    reg::free_temp_reg($1->rdest);
  }
      T_COMMA expr_comma_list
  {
    attribute *expr_list = new attribute;
    expr_list->mipsCode = $1->mipsCode + $4->mipsCode;
    delete $1, $4;
    $$ = expr_list;
  }
     ;

opt_expr: expr
  {
    attribute *opt_expr = new attribute;
    opt_expr->mipsCode = " sw " + string(REGISTER[$1->rdest]) + ", " + int_to_str(tmp_pos) + "($fp)  #pass argument\n"; 
    opt_expr->rdest = $1->rdest;
    opt_expr->type = $1->type;
    tmp_pos = tmp_pos - 4;
    reg::free_temp_reg($1->rdest);
    $$ = opt_expr;
  }
     | /* empty */ 
  {
    attribute *opt_expr = new attribute;
    opt_expr->rdest = -1;
    $$ = opt_expr;
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
    stringconst->lexeme = g_code.next_str_label(*$1);
    $$ = stringconst;
  }
     ;

assign_comma_list: assign
  {
  }
     | assign T_COMMA assign_comma_list
  {
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
    int tmp_reg = reg::get_temp_reg(-1, -1);
    g_code.add(" move " + string(REGISTER[tmp_reg]) + ", " + string(REGISTER[$3->rdest]) + "\n");
    lvalue->array_index = tmp_reg; 
    $$ = lvalue;
  }
     ;

expr: lvalue
  {
    $$ = expr_lvalue($1);
  }
     | method_call
  {
    attribute *expr = new attribute;
    int tmp_reg = reg::get_temp_reg(-1, -1);
    g_code.add(" move " + string(REGISTER[tmp_reg]) + ", $v0  # move return value to t reg\n");
    expr->rdest = tmp_reg;
    //cout << "start get type\n";
    expr->type = $1->type; 
    // cout << "end get type " << $1->type << "\n";
    $$ = expr;
  }
     | constant
  {
    //cout << "Constant: " << $1->lexeme << endl;
    $$ = constant(&($1->lexeme), $1->type);
	delete $1;
  }
     | expr T_PLUS expr
  {
    $$ = binop_expr("addu", "+", $1, $3);
  }
     | expr T_MINUS expr
  {
    $$ = binop_expr("subu", "-", $1, $3);
  }
     | expr T_MULT expr
  {
    $$ = binop_expr("mul", "*", $1, $3);
  }
     | expr T_DIV expr
  {
    $$ = binop_expr("divu", "/", $1, $3);
  }
     | expr T_LEFTSHIFT expr
  {
    $$ = binop_expr("sllv", "<<", $1, $3);
  }
     | expr T_RIGHTSHIFT expr
  {
    $$ = binop_expr("srlv", ">>", $1, $3);
  }
     | expr T_ROT expr
  {
    
    // this should include either a mod instruction or a branch,
    // removed the correct implementation here due to overlap with hw4
	//g_code.add(string(" bltz " + $3->rdest + string(", ") + *label + string("\n")));
	int bltz_instr = next_instr("");
	$$ = binop_expr("rol", "rot", $1, $3);
	string* label = next_label();
	g_code.get(bltz_instr) = string(" bltz ") + REGISTER[$3->rdest] + string(", ") + *label + string("\n");
	//g_code.add(*label + string(":\n"));
	attribute* tmp = unary_expr("neg", "-", $3);
	$$ = binop_expr("ror", "rot", $1, tmp);
	delete tmp, label;
    //if ($3->opcode == "neg") {
    //  $$ = binop_expr("ror", "rot", $1, $3); // rotate right if right expr is -1
    //} else {
    //  $$ = binop_expr("ror", "rot", $1, $3); // else rotate left
    //}
  }
     | expr T_MOD expr
  {
    $$ = binop_expr("rem", "%", $1, $3);
  }
     | expr T_LT expr
  {
    $$ = binop_expr("slt", "<", $1, $3);
  }
     | expr T_GT expr
  {
    $$ = binop_expr("sgt", ">", $1, $3);
  }
     | expr T_LEQ expr
  {
    $$ = binop_expr("sle", "<=", $1, $3);
  }
     | expr T_GEQ expr
  {
    $$ = binop_expr("sge", ">=", $1, $3);
  }
     | expr T_EQ expr
  {
    $$ = binop_expr("seq", "==", $1, $3);
  }
     | expr T_NEQ expr
  {
    $$ = binop_expr("sne", "!=", $1, $3);
  }
     | expr T_AND expr
  {
    $$ = binop_expr("and", "&&", $1, $3);
  }
     | expr T_OR  expr
  {
    $$ = binop_expr("or", "||", $1, $3);
  }
     | T_MINUS expr %prec UMINUS 
  {
    $$ = unary_expr("neg", "-", $2);
  }
     | T_NOT expr
  {
    attribute *imm = new attribute;
    imm->opcode_type = string("none");
    imm->rdest = ZERO;
	imm->type = T_BOOL;
    $$ = binop_expr("seq", "!", $2, imm);
  }
     | T_LPAREN expr T_RPAREN
  {
    $$ = $2;
  }
     ;

constant: T_INTCONSTANT
  {
    attribute *constant = new attribute;
    constant->lexeme = *$1;
	constant->type = INT;
    $$ = constant;
  }
     | T_CHARCONSTANT
  {
	attribute *constant = new attribute;
    constant->lexeme = *$1;
	constant->type = INT;
    $$ = constant;

//    $$ = constant($1, T_CHARCONSTANT);
  }
     | T_TRUE
  {
	attribute *constant = new attribute;
    constant->lexeme = string("1");
	constant->type = BOOL;
    $$ = constant;


    //string trueval("1");
    //$$ = constant(&trueval, T_BOOL);
  }
     | T_FALSE
  {
	attribute *constant = new attribute;
    constant->lexeme = string("0");
	constant->type = BOOL;
    $$ = constant;


    //string falseval("0");
    //$$ = constant(&falseval, T_BOOL);
  }
     ;


%%


