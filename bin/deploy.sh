#!/usr/bin/env bash
# must be run from the root

npx hardhat run scripts/deploy-$1.js --network $2
