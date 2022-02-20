#!/usr/bin/env bash
# must be run from the root

USEMATICKEY=1 NONCE=$2 RECIPIENT=$3 AMOUNT=$4 npx hardhat run scripts/deliver.js --network $1
