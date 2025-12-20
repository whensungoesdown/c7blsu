#!/bin/bash
echo run tests
echo

cd test1_store
echo "test1_store"
if ./simulate.sh | grep PASS; then
	printf ""
else
	printf "Fail!\n"
	exit
fi
echo ""
cd ..


cd test2_load
echo "test2_load"
if ./simulate.sh | grep PASS; then
	printf ""
else
	printf "Fail!\n"
	exit
fi
echo ""
cd ..


