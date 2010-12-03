
#include <string>
#include <iostream>
#include <map>
#include <vector>

using namespace std;

class method_descriptor {

public:
  string method_id;
  int return_type;
  map<string, int> args;   // map<id, type>
  int var_count;
  vector<int> saved_regs;
  vector<int> saved_tmp;
  int hi_ptr;
  int lo_ptr;
  int stack_size;
  // Initialize
  method_descriptor(string name, int r_type, map<string, int> arglist) {

    method_id = name;
    return_type = r_type;
    args = arglist;
    var_count = 0;
    saved_regs.clear();
  }

};

