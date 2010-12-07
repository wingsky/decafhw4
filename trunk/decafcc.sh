#!/bin/bash

if [ ! -f decafexpr-codegen ]
then
	make
fi

./decafexpr-codegen < $1 > tmp.m
if [ $? == 0 ]
then
	spim -file tmp.m
fi

rm -f tmp.m
