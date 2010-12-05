
#include <string>
#include <iostream>

using namespace std;

class descriptor {
public:
  int type;
  string name;
  int rdest;
  string memoryaddr;
  int global;
  int array_length;
  int offset;

  descriptor(string t) {
	name = t;
    //type = t;
    offset = 0;
    rdest = -1;
    memoryaddr = "";
    global = 0;
    array_length = 0;
  }

  descriptor(string n, int t, int r, string ma) {
    name = n;
	  type = t;
    rdest = r;
    memoryaddr = ma;
    global = 0;
    offset = 0;
    array_length = 0;
  }

  void print() {
    cerr << "name: " << name << endl;
    cerr << "register: " << rdest << endl;
    cerr << "memory address: " << memoryaddr << endl;
  }
};

