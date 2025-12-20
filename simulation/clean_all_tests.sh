#!/bin/bash
echo clean tests
echo

cd test1_store
echo "test1_store"
./clean.sh
echo ""
cd ..


cd test2_load
echo "test2_load"
./clean.sh
echo ""
cd ..


