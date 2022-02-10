#!/usr/bin/env bash
# must be run from the root

npx hardhat flatten contracts/$1.sol > ./$1-flatten.sol
