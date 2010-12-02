
#include <string>
#include <iostream>
#include <map>
#include <vector>

using namespace std;

class method_descriptor {

public:
  string method_id;
  string return_type;
  map<string, string> args;
  int var_count;
  vector<int> saved_regs;

  // Initialize
  method_descriptor(string name, string r_type, map<string, string> arglist) {

    method_id = name;
    return_type = r_type;
    args = arglist;
    var_count = 0;
  }

};

