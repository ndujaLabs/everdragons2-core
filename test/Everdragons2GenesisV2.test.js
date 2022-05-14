const {expect, assert} = require("chai")
const _ = require('lodash')
const keccak256 = require('keccak256')
const {MerkleTree} = require('merkletreejs')
const fs = require('fs-extra')
const path = require('path')

const {
  initEthers,
  assertThrowsMessage,
  signPackedData,
  normalize,
  getTimestamp,
  increaseBlockTimestampBy
} = require('./helpers')
const whitelist = require('./fixtures/whitelist.json');

describe("Everdragons2GenesisV2", async function () {

  let Everdragons2Genesis
  let Everdragons2GenesisV2
  let everdragons2Genesis
  let StakingPool
  let pool
  let GenesisFarm
  let genesisFarm
  let owner, wallet, buyer1, buyer2, buyer3, treasury, member, beneficiary1, beneficiary2,
      whitelisted1, whitelisted2, whitelisted3, openSea

  before(async function () {
    [owner, wallet, buyer1, buyer2, buyer3, treasury, member, beneficiary1, beneficiary2,
      whitelisted1, whitelisted2, whitelisted3, openSea] = await ethers.getSigners()
    Everdragons2Genesis = await ethers.getContractFactory("Everdragons2Genesis")
    Everdragons2GenesisV2 = await ethers.getContractFactory("Everdragons2GenesisV2Mock")
    GenesisFarm = await ethers.getContractFactory("GenesisFarm")
    StakingPool = await ethers.getContractFactory("StakingPoolMock")
    initEthers(ethers)
  })

  async function initAndDeploy(saleStartAt) {
    if (!saleStartAt) {
      saleStartAt = (await getTimestamp()) + 10
    }
    everdragons2Genesis = await upgrades.deployProxy(Everdragons2Genesis, []);
    await everdragons2Genesis.deployed()
    expect(await everdragons2Genesis.contractURI(), 'https://img.everdragons2.com/e2gt/0')
    genesisFarm = await GenesisFarm.deploy(
        everdragons2Genesis.address,
        25, // maxForSale
        10, // maxClaimable
        normalize(10), // price in MATIC
        saleStartAt)
    await genesisFarm.deployed()
    await everdragons2Genesis.setManager(genesisFarm.address)
  }

    beforeEach(async function () {
      await initAndDeploy()
      await increaseBlockTimestampBy(11)
    })

    it("upgrade without issues", async function () {

      expect(await genesisFarm.connect(buyer1).buyTokens(3, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(3)
      }))
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 11)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 12)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 13)

      expect(await genesisFarm.nextTokenId()).equal(14)

      const upgraded = await upgrades.upgradeProxy(everdragons2Genesis.address, Everdragons2GenesisV2);
      await upgraded.deployed();

      expect(everdragons2Genesis.address).equal(upgraded.address)

      everdragons2Genesis = Everdragons2GenesisV2.attach(upgraded.address)

      expect(await everdragons2Genesis.airdrop([buyer2.address, buyer3.address, buyer3.address], [14, 15, 16]))
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer2.address, 14)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer3.address, 15)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer3.address, 16)


      pool = await StakingPool.deploy(everdragons2Genesis.address)
      await pool.deployed()

      await everdragons2Genesis.endMint()

      await everdragons2Genesis.setPool(pool.address)
      await pool.connect(buyer1).stakeEvd2(13)
      expect(await upgraded.isStaked(13)).equal(true)
      expect(await upgraded.getStaker(13)).equal(pool.address)

      expect(everdragons2Genesis.connect(buyer1).approve(openSea.address, 13)).revertedWith("Dragon is staked")

      expect(everdragons2Genesis.connect(buyer1).setApprovalForAll(openSea.address, true)).revertedWith("At least one dragon is staked")

      await pool.connect(buyer1).unstakeEvd2(13)
      await everdragons2Genesis.connect(buyer1).approve(openSea.address, 13)
      expect(await everdragons2Genesis.getApproved(13)).equal(openSea.address)

    })


})
