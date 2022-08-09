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

describe("Everdragons2GenesisV3", async function () {

  let Everdragons2Genesis
  let Everdragons2GenesisV2
  let Everdragons2GenesisV3
  let Everdragons2GenesisV4
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
    Everdragons2GenesisV2 = await ethers.getContractFactory("Everdragons2GenesisV2")
    Everdragons2GenesisV3 = await ethers.getContractFactory("Everdragons2GenesisV3")
    Everdragons2GenesisV4 = await ethers.getContractFactory("Everdragons2GenesisV4")
    GenesisFarm = await ethers.getContractFactory("GenesisFarm")
    StakingPool = await ethers.getContractFactory("StakingPoolMockV3")
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

      await genesisFarm.connect(buyer2).buyTokens(1, {
        value: await genesisFarm.price()
      })

      let upgraded = await upgrades.upgradeProxy(everdragons2Genesis.address, Everdragons2GenesisV2);
      await upgraded.deployed();

      expect(everdragons2Genesis.address).equal(upgraded.address)

      upgraded = await upgrades.upgradeProxy(everdragons2Genesis.address, Everdragons2GenesisV3);
      await upgraded.deployed();

      expect(everdragons2Genesis.address).equal(upgraded.address)

      everdragons2Genesis = Everdragons2GenesisV3.attach(upgraded.address)

      expect(await everdragons2Genesis.connect(buyer1).transferFrom(buyer1.address, buyer2.address, 12))
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(buyer1.address, buyer2.address, 12)


      pool = await StakingPool.deploy(everdragons2Genesis.address)
      await pool.deployed()

      await assertThrowsMessage(pool.connect(buyer1).stakeEvd2(13), "Forbidden")

      await everdragons2Genesis.setLocker(pool.address)
      await assertThrowsMessage(pool.connect(buyer1).stakeEvd2(13), "Locker not approved")

      await everdragons2Genesis.connect(buyer1).setApprovalForAll(pool.address, true)

      expect(await pool.connect(buyer1).stakeEvd2(13))
          .to.emit(everdragons2Genesis, 'Locked')

      await everdragons2Genesis.connect(buyer2).approve(pool.address, 14)
      await pool.connect(buyer2).stakeEvd2(14)
      expect(await upgraded.isLocked(14)).equal(true)
      expect(await upgraded.lockerOf(14)).equal(pool.address)

      expect(everdragons2Genesis.connect(buyer2).approve(openSea.address, 14)).revertedWith("locked asset")

      expect(everdragons2Genesis.connect(buyer2).setApprovalForAll(openSea.address, true)).revertedWith("at least one asset is locked")

      await pool.connect(buyer2).unstakeEvd2(14)
      await everdragons2Genesis.connect(buyer2).approve(openSea.address, 14)
      expect(await everdragons2Genesis.getApproved(14)).equal(openSea.address)

      // upgrading to V4

      upgraded = await upgrades.upgradeProxy(everdragons2Genesis.address, Everdragons2GenesisV4);
      await upgraded.deployed();
      //
      expect(everdragons2Genesis.address).equal(upgraded.address)
      expect(await everdragons2Genesis.ownerOf(12)).equal(buyer2.address)


    })


})
