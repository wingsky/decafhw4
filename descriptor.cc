
#include <string>
#include <iostream>

using namespace std;

class descriptor {
public:
  string type;
  string rdest;
  string memoryaddr;

  descriptor(string t) {
    type = t;
    rdest = "";
    memoryaddr = "";
  }

  descriptor(string t, string r, string ma) {
    type = t;
    rdest = r;
    memoryaddr = ma;
  }

  void print() {
    cerr << "type: " << type << endl;
    cerr << "register: " << rdest << endl;
    cerr << "memory address: " << memoryaddr << endl;
  }
};

