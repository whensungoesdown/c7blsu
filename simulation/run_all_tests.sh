#!/bin/bash
echo run tests
echo


cd test1_store
echo "test1_store"
result=$(./simulate.sh)
if echo "$result" | grep "FAIL"; then
    printf "FAIL!\n"
    exit 1
elif echo "$result" | grep "PASS"; then
    printf "PASS!\n"
else
    printf "Unknown result\n"
    exit 1
fi
echo ""
cd ..


cd test2_load
echo "test2_load"
result=$(./simulate.sh)
if echo "$result" | grep "FAIL"; then
    printf "FAIL!\n"
    exit 1
elif echo "$result" | grep "PASS"; then
    printf "PASS!\n"
else
    printf "Unknown result\n"
    exit 1
fi
echo ""
cd ..

