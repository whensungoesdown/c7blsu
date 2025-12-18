#!/bin/bash
echo run tests
echo

cd test0_simplehit
echo "test0_simplehit"
if ./simulate.sh | grep PASS; then
	printf ""
else
	printf "Fail!\n"
	exit
fi
echo ""
cd ..


cd test1_miss_lfb
echo "test1_miss_lfb"
if ./simulate.sh | grep PASS; then
	printf ""
else
	printf "Fail!\n"
	exit
fi
echo ""
cd ..


cd test2_miss_allocate
echo "test2_miss_allocate"
if ./simulate.sh | grep PASS; then
	printf ""
else
	printf "Fail!\n"
	exit
fi
echo ""
cd ..
