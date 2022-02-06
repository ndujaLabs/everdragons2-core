#!/usr/bin/env bash
# must be run from the root

rm -rf cache
rm -rf artifacts
npx hardhat compile

node scripts/exportABIs.js
cp export/ABIs.json ../app-everdragons2/client/config/.
cp export/deployed.json ../app-everdragons2/client/config/.
