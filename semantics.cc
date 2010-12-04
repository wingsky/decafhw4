
#include <string>
#include <map>
#include <list>
#include <fstream>
#include <sstream>
#include <cstdlib>
#include <stdexcept>
#include <iterator>
#include <algorithm>

using namespace std;

class semantics {

public:

  semantics() {
    istringstream sin(symbol_registers);
    copy(istream_iterator<string>(sin), istream_iterator<string>(), 
	 back_inserter(symbol_register_list));
  }

  string final(attribute top) {
    return string(".text\n") + string(".globl main\n") + string("main:\n") + top.asmcode();
  }

  void new_symtbl() {
    symbol_table new_symtbl;
    symtbl.push_front(new_symtbl);
  }

  void remove_symtbl() {
    symbol_table tbl;
    if (symtbl.empty())
      throw runtime_error("no symbol table to remove here!");
    else
      tbl = symtbl.front();
    for (symbol_table::iterator i = tbl.begin(); i != tbl.end(); ++i)
      delete(i->second);
    symtbl.pop_front();
  }

  void enter_symtbl(string ident, int type, int rdest, string memoryaddr) {
    symbol_table* tbl;
    symbol_table::iterator find_ident;

    if (symtbl.empty())
      throw runtime_error("no symbol table created yet!");

    tbl = &symtbl.front();
    if ((find_ident = tbl->find(ident)) != tbl->end()) {
      cerr << "Warning: redefining previously defined identifier: " << ident << endl;
      delete(find_ident->second);
      tbl->erase(ident);
    }
    descriptor* d = new descriptor(ident, type, rdest, memoryaddr);
    (*tbl)[ident] = d;
  }

  descriptor* access_symtbl(string ident) {
    for (symbol_table_list::iterator i = symtbl.begin(); i != symtbl.end(); ++i) {
      symbol_table::iterator find_ident;
      if ((find_ident = i->find(ident)) != i->end())
	return find_ident->second;
    }
    return NULL;
  }

  string first_symbol_register() {
    if (symbol_register_list.empty())
      throw runtime_error("semantic action error: no more temporary registers");
    return symbol_register_list.front();
  }

  void remove_first_symbol_register() {
    if (symbol_register_list.empty())
      throw runtime_error("semantic action error: no more temporary registers");
    symbol_register_list.pop_front();
  }

  void enter_method(string name, int r_type, vector< pair<string, int> > arg) {
    
    method_descriptor* d = new method_descriptor(name, r_type, arg);
    mtdtbl[name] = d;

  }

  string calc_addr(long offset) {
    string tmp_s = "";
    return tmp_s;
  }
  string spill_reg(int reg, long offset) {
    
    string tmp_s = "";

    if ((reg < S0) || (reg > S7)) {
      cout << "ERROR: Cannot spill registers other than $s0-$s7\n";
      exit(1);
    }
    // Currently one register can only hold one variable
    string var = regtbl[reg].front();
    // Get addr in the heap
    string addr_s = calc_addr(offset);

    tmp_s += "sw " + string(REGISTER[reg]) + ", " + addr_s + "($gp)\n";

    descriptor *d = access_symtbl(var);
    d->memoryaddr = addr_s;
    d->rdest = -1;
    regtbl[reg].clear();
  }

  typedef map<string, method_descriptor* > method_table;
  method_table mtdtbl; 

private:
  list<string> symbol_register_list;
  typedef map<string, descriptor* > symbol_table;
  typedef list<symbol_table > symbol_table_list;
  symbol_table_list symtbl;

};

