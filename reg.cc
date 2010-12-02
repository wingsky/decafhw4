#include<list>
#include "register-def.h"

using namespace std;


typedef list<string> var_list;
static var_list regtbl[32];

class reg {

public:

  static void init_regtbl() {
    for (int i = S0; i <= T9; i++) {
      //cout << "bf clear\n";
      regtbl[i].clear();
      //cout << "af clear\n";
    }
  }

  // Called when allocating temp registers 
  static int get_temp_reg(int t1, int t2) {

    if ((t1 >= T0) && (t1 <= T9)) {
      regtbl[t1].clear();
      regtbl[t1].push_front("");
      return t1;
    }
    else if ((t2 >= T0) && (t2 <= T9)) {
      regtbl[t2].clear();
      regtbl[t2].push_front("");
      return t2;
    }
    else {
      for (int i = T0; i <=T9; i++) {
        if (regtbl[i].empty()) {
          regtbl[i].push_front("");
          return i;
        }
      }
    }
    // otherwise, we run out of registers
    fprintf(stderr, "ERROR: Run out of $t registers!\n");
    exit(1);

  }

  static void free_temp_reg(int t) {
    if ((t >= T0) && (t <= T9)) {
      regtbl[t].clear();
    }
    return;
  }

  static int get_empty_reg(string id_string) {

    for (int i = S0; i <= S7; i++) {
      if (regtbl[i].empty()) {
        regtbl[i].push_front(id_string);
        //cout << "REGTBL: " << i << " " << id_string << endl;
        return i;
      }
    }

    fprintf(stderr, "ERROR: Run out of $s registers!\n");
    exit(1);
  }
};
