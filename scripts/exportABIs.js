// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const fs = require('fs-extra')
const path = require('path')

async function main() {

  const ABIs = {
    when: (new Date).toISOString(),
    contracts: {}
  }

  const contractsDir = await fs.readdir(path.resolve(__dirname, '../artifacts/contracts'))

  for (let name of contractsDir) {
    let tmp = name.split('.')
    if (tmp[1] !== 'sol') continue
    name = tmp[0]
    let source = path.resolve(__dirname, `../artifacts/contracts/${name}.sol/${name}.json`)
    let json = require(source)
    ABIs.contracts[name] = json.abi
  }
  await fs.writeFile(path.resolve(__dirname, '../export/ABIs.json'), JSON.stringify(ABIs, null, 2))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

