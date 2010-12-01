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
		//cout << "ADD: "<< c;
		code_list.push_back(c);
		//print();
		//cout << endl;
	}

	string& get(int i){
		return code_list[i];
	}

	void remove(){
		code_list.pop_back();
	}

	void print(){
		string s;
		for(vector<string>::iterator i = code_list.begin(); i != code_list.end(); ++i){
			s += *i;
		}

		cout << s;
	}

	void backpatch(list<int>& l, string* label){
		for(list<int>::iterator i = l.begin(); i != l.end(); ++i){
			if(code_list[*i].find("jal") != string::npos ||
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
