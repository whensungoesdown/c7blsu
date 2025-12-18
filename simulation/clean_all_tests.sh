#!/bin/bash
echo clean tests
echo

cd test0_simplehit
echo "test0_simplehit"
./clean.sh
echo ""
cd ..


cd test1_miss_lfb
echo "test1_miss_lfb"
./clean.sh
echo ""
cd ..


cd test2_miss_allocate
echo "test1_miss_allocate"
./clean.sh
echo ""
cd ..



