#!/usr/bin/env bash
# must be run from the root

npx hardhat verify --show-stack-traces --network $1
#--constructor-args arguments.js $2
