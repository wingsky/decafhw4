
lexlib=fl
yacclib=y
bindir=.
test=..
rm=/bin/rm -f
mv=/bin/mv -f
targets=
cpptargets=decafexpr-codegen

all: $(targets) $(cpptargets)

$(targets): %: %.y
	@echo "compiling yacc file:" $<
	@echo "output file:" $@
	bison -o$@.tab.c -d $<
	flex -o$@.lex.c $@.lex
	gcc -o $(bindir)/$@ $@.tab.c $@.lex.c -l$(yacclib) -l$(lexlib)
	$(rm) $@.tab.c $@.tab.h $@.lex.c

$(cpptargets): %: %.y
	@echo "compiling cpp yacc file:" $<
	@echo "output file:" $@
	bison -b $@ -d $<
	$(mv) $@.tab.c $@.tab.cc
	flex -o$@.lex.cc $@.lex
	g++ -o $(bindir)/$@ $@.tab.cc $@.lex.cc -l$(yacclib) -l$(lexlib)
	$(rm) $@.tab.h $@.tab.cc $@.lex.cc

test: $(targets) $(cpptargets)
	@echo "Question 4 ..."
	cat decaf-sym-input.txt  | $(bindir)/decaf-sym
	@echo "Question 5 ..."
	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-0.txt > expr-testfile-0.mips
	diff expr-testfile-0.mips $(test)/expr-testfile-0.mips
	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-1.txt > expr-testfile-1.mips
	diff expr-testfile-1.mips $(test)/expr-testfile-1.mips
	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-2.txt > expr-testfile-2.mips
	diff expr-testfile-2.mips $(test)/expr-testfile-2.mips
	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-3.txt > expr-testfile-3.mips
	diff expr-testfile-3.mips $(test)/expr-testfile-3.mips
	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-5.txt > expr-testfile-5.mips
	diff expr-testfile-5.mips $(test)/expr-testfile-5.mips
	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-6.txt > expr-testfile-6.mips
	diff expr-testfile-6.mips $(test)/expr-testfile-6.mips

testall: $(targets) $(cpptargets)
	@echo "Question 1 ..."
	cat catalan-mips.txt
	@echo "Question 2 ..."
	cat symboltable.cc
	@echo "Question 3 ..."
	cat type-inherit-test.txt | $(bindir)/type-inherit
	@echo "Question 4 ..."
	cat decaf-sym-input.txt  | $(bindir)/decaf-sym
	@echo "Question 5 ..."
	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-0.txt > expr-testfile-0.mips
	diff expr-testfile-0.mips $(test)/expr-testfile-0.mips
	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-1.txt > expr-testfile-1.mips
	diff expr-testfile-1.mips $(test)/expr-testfile-1.mips
	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-2.txt > expr-testfile-2.mips
	diff expr-testfile-2.mips $(test)/expr-testfile-2.mips
	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-3.txt > expr-testfile-3.mips
	diff expr-testfile-3.mips $(test)/expr-testfile-3.mips
	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-5.txt > expr-testfile-5.mips
	diff expr-testfile-5.mips $(test)/expr-testfile-5.mips
	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-6.txt > expr-testfile-6.mips
	diff expr-testfile-6.mips $(test)/expr-testfile-6.mips
#	$(bindir)/decafexpr-codegen < $(test)/expr-testfile-4.txt > expr-testfile-4.mips

clean:
	$(rm) $(targets) $(cpptargets)
	$(rm) *.tab.h *.tab.c *.lex.c
	$(rm) *.mips

