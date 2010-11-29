
#include <string>
#include <iostream>

using namespace std;

class descriptor {
public:
  string type;
  int rdest;
  string memoryaddr;
  int global;
  int array_length;

  descriptor(string t) {
    type = t;
    rdest = -1;
    memoryaddr = "";
    global = 0;
    array_length = 0;
  }

  descriptor(string t, int r, string ma) {
    type = t;
    rdest = r;
    memoryaddr = ma;
    global = 0;
    array_length = 0;
  }

  void print() {
    cerr << "type: " << type << endl;
    cerr << "register: " << rdest << endl;
    cerr << "memory address: " << memoryaddr << endl;
  }
};

