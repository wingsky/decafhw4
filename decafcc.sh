#!/bin/sh

if [ ! -f decafexpr-codegen ]
then
	make
fi

./decafexpr-codegen < $1 > tmp.m
spim -file tmp.m
rm -f tmp.m
