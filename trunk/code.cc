#include <list>
#include <string>

using namespace std;

class code{

private:
	list<string> code_list;


public:
	code(){
	}

	void add(const string& c){
		code_list.push_back(c);
	}

	void print(){
		string s;
		s += string(".text\n") + string(".globl main\n");
		for(list<string>::iterator i = code_list.begin(); i != code_list.end(); ++i){
			s += *i;
		}

		cout << s;
	}
};
