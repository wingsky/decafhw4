#include <sstream>
#include <iostream>
#include <list>
#include <string>
#include <vector>

using namespace std;

class code{

private:
	vector<string> code_list;


public:
	code(){
	}

	int get_current_instr(){
		return code_list.size() - 1;
	}

	int get_next_instr(){
		return code_list.size();
	}

	void add(const string& c){
		code_list.push_back(c);
	}

	void print(){
		string s;
		s += string(".text\n") + string(".globl main\n");
		for(vector<string>::iterator i = code_list.begin(); i != code_list.end(); ++i){
			s += *i;
		}

		cout << s;
	}

	void backpatch(list<int>& l, int instr){
		for(list<int>::iterator i = l.begin(); i != l.end(); ++i){
			code_list[*i] += string(" ") + int_to_str(instr) + string("\n");
		}
	}

private:
	string int_to_str(int i){
		stringstream out;
		out << i;
		return out.str();
	}
};
