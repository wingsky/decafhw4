#include <sstream>
#include <iostream>
#include <list>
#include <string>
#include <vector>
#include <map>

using namespace std;

static const char* label_prefix = "str";

class code{

private:
	vector<string> code_list;
	map<string, string> str_constant_list;

	int label_count;


public:
  vector<string> global_decl;

	code(){
		label_count = 0;
	}

	int get_current_instr(){
		return code_list.size() - 1;
	}

	int get_next_instr(){
		return code_list.size();
	}
  
	string next_str_label(string s){
		string new_label = string(label_prefix) + int_to_str(++label_count);
		str_constant_list.insert(pair<string, string>(s, new_label+string(":")));

		return new_label;
	}


	void add(const string& c){
		//cout << "ADD: "<< c;
		code_list.push_back(c);
		//print();
		//cout << endl;
    //cout << c << endl;
	}

  void insert(int pos, const string& c) {
    vector<string>::iterator it;
    it = code_list.begin();
    for (int i = 0; i < pos; i++) {
      it++;
    }

    code_list.insert(it, c);
  }

	string& get(int i){
		return code_list[i];
	}

	void remove(){
		code_list.pop_back();
	}

	void print(){
		string s;
		s += string("\t.data\n");
		for(map<string, string>::iterator i = str_constant_list.begin(); i != str_constant_list.end(); ++i){
			s += i->second + string(" .asciiz ") + i->first + string("\n");
		}
    
    for (vector<string>::iterator i = global_decl.begin(); i != global_decl.end(); i++) {
      s += *i;
    }

		s += "\t.text\n";
		for(vector<string>::iterator i = code_list.begin(); i != code_list.end(); ++i){
			s += *i;
		}

		cout << s;
	}

	void backpatch(list<int>& l, string* label){
		for(list<int>::iterator i = l.begin(); i != l.end(); ++i){
			if(code_list[*i].find("j") != string::npos ||
					code_list[*i].find("beq") != string::npos){
				int last_pos = code_list[*i].size();
				code_list[*i].erase(last_pos - 1, 1);
				last_pos = code_list[*i].size();
				code_list[*i].erase(last_pos - 1, 1);

				code_list[*i] += *label + string("\n");

			}
		}

	}

private:
	string int_to_str(int i){
		stringstream out;
		out << i;
		return out.str();
	}
};
