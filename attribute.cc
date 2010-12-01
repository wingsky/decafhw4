
#include <string>
#include <fstream>
#include <sstream>
#include <iostream>
#include <list>
#include <iterator>
#include <algorithm>
#include <stdexcept>
#include "reg.cc"

using namespace std;

static const string s_pad = " ";
static const string s_comma = ", ";
static const string s_newline = "\n";
static const string mips_registers = "$t0 $t1 $t2 $t3 $t4 $t5 $t6 $t7 $t8 $t9";
static const string symbol_registers = "$s0 $s1 $s2 $s3 $s4 $s5 $s6 $s7";


class attribute {

public:

  string token;
  string lexeme;
  string array_size;
  int array_index;

  string opcode_type; // is it an immediate load, or register load, etc.
  string opcode;      // MIPS opcode
  int rdest;       // destination register
  int rsrc;        // source register
  int rsrc2;
  string rt;          // temporary register
  string imm;         // immediate value
  string label;       // label for goto
  string address;     // memory address
  string function_label; // label for function calls: jal, etc.
  
  string mipsCode;     // MIPS code for current attribute

  list<attribute> children;
  
  list<string> next_free_register;

  list<int> true_list;
  list<int> false_list;
  list<int> next_list;
  list<int> break_list;
  list<int> continue_list;

  int inherited; // non-zero means this attribute is inherited

  // constructor sets up the various variables and the free register list
  attribute() {
    token   = "";
    lexeme  = "";
    array_size = "";
    array_index = -1;
 
    opcode_type = "";
    opcode  = "";
    rdest   = -1;
    rsrc    = -1;
    rsrc2   = -1;
    rt      = "";
    imm     = "";
    label   = "";
    address = "";
    function_label = "";
    mipsCode = "";

    inherited = 0;
  }
/*
  void init_free_registers() {
    istringstream sin(mips_registers);
    copy(istream_iterator<string>(sin), istream_iterator<string>(), 
	 back_inserter(next_free_register));
  }

  string first_free_register() {
    if (next_free_register.empty())
      throw runtime_error("semantic action error: no more temporary registers");
    return next_free_register.front();
  }

  void remove_first_free_register() {
    if (next_free_register.empty())
      throw runtime_error("semantic action error: no more temporary registers");
    next_free_register.pop_front();
  }

  void add_free_register(string reg) {
    next_free_register.push_front(reg);
  }

  void result_register(string reg) {
    if (rdest == reg)
      return;

    // reset used registers
    init_free_registers();
    while (first_free_register() != reg)
      remove_first_free_register();
    if (next_free_register.empty())
      throw runtime_error("semantic action error: no more temporary registers");

    rdest = first_free_register();
    for (list<attribute>::iterator i = children.begin(); i != children.end(); ++i) {
      rsrc = first_free_register();
      i->result_register(rsrc);
      remove_first_free_register();
    }
  }
*/
  void add_child(attribute child) {
    children.push_back(child);
  }

  void mipsInstruction() {
    if (opcode_type == "imm")
      mipsInstruction_imm();
    if (opcode_type == "reuse")
      mipsInstruction_reuse();
    if (opcode_type == "load")
      mipsInstruction_load();
    if (opcode_type == "none")
      mipsInstruction_none();
  }

 // immediate move into register
  void mipsInstruction_imm() {
    mipsCode = s_pad + opcode + s_pad + string(REGISTER[rdest]) + s_comma + imm + s_newline;
  }

  // opcode with 3 arguments, reuses one register so only uses a total of two registers
  void mipsInstruction_reuse() {
    mipsCode = s_pad + opcode + s_pad + string(REGISTER[rdest]) + s_comma + string(REGISTER[rsrc]) + s_comma + string(REGISTER[rsrc2]) + s_newline;
  }

  // load from one register to another
  void mipsInstruction_load() {
    mipsCode = s_pad + opcode + s_pad + string(REGISTER[rdest]) + s_comma + string(REGISTER[rsrc]) + s_newline;
  }

  // do nothing
  void mipsInstruction_none() {
    if (opcode == "")
      mipsCode = "";
    else
      mipsCode = s_pad + opcode + s_newline;
  }

  string asmcode() {
    //string s; //mipsInstruction(); //for (list<attribute>::iterator i = children.begin(); i != children.end(); ++i)
    //  s += (*i).asmcode();
    //return s + mipsCode;
	mipsInstruction();
	return mipsCode;
  }

  void print_list(const string& s){
	if(s == "true")
		print_list(true_list);
	else if(s == "false")
		print_list(false_list);
	else if(s == "next")
		print_list(next_list);

  }

   void print_list(list<int>& l){
	for(list<int>::iterator i = l.begin(); i != l.end(); ++i){
		cout << *i << endl;
	}
  }


  void print(const char* s) { 
    cerr << endl;
    cerr << s << ": token: " << token << endl;
    cerr << s << ": lexeme: " << lexeme << endl;
    cerr << endl;
    cerr << s << ": opcode_type: " << opcode_type << endl;
    cerr << s << ": opcode: " << opcode << endl;
    cerr << s << ": rdest: " << rdest << endl;
    cerr << s << ": rsrc: " << rsrc << endl;
    cerr << s << ": rt: " << rt << endl;
    cerr << s << ": imm: " << imm << endl;
    cerr << s << ": label: " << label << endl;
    cerr << s << ": asmcode: " << endl;
    cerr << asmcode();
  }

  void printtree(int n) {
    for (int i=0; i<=n; i++) cerr << "\t";
    print("(");
    for (list<attribute>::iterator i = children.begin(); i != children.end(); ++i)
      (*i).printtree(n+1);
    print(")");

  }

};

