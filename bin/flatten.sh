#!/usr/bin/env bash

if [[ ! -d "./flattened" ]]; then
  mkdir flattened
fi
FOLDER=""
if [[ "$2" != "" ]]; then
  FOLDER=$2/
fi
npx hardhat flatten contracts/$FOLDER$1.sol > ./flattened/$1-flattened.sol
bin/clean-licenses-in-flattened.js $1
