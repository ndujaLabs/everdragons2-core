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

describe.skip("Everdragons2PfP", async function () {

  let Everdragons2Genesis
  let Everdragons2GenesisV2
  let everdragons2Genesis
  let Everdragons2PfP
  let everdragons2PfP
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
    Everdragons2PfP = await ethers.getContractFactory("Everdragons2PfP")
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
        3000, // maxForSale
        10, // maxClaimable
        normalize(10), // price in MATIC
        saleStartAt)
    await genesisFarm.deployed()
    await everdragons2Genesis.setManager(genesisFarm.address)
    everdragons2PfP = await upgrades.deployProxy(Everdragons2PfP, []);
    await everdragons2PfP.setGenesisToken(everdragons2Genesis.address);
  }

    beforeEach(async function () {
      await initAndDeploy()
      await increaseBlockTimestampBy(11)
    })

    it("claim PfP tokens", async function () {

      expect(await genesisFarm.connect(buyer1).buyTokens(20, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(20)
      }))
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 11)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 12)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 13)

      await genesisFarm.connect(buyer1).buyTokens(20, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(20)
      })
      await genesisFarm.connect(buyer1).buyTokens(20, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(20)
      })
      await genesisFarm.connect(buyer1).buyTokens(20, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(20)
      })

      expect(await everdragons2PfP.connect(buyer1).claim())
          .to.emit(everdragons2PfP, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 11)
          .to.emit(everdragons2PfP, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 12)
          .to.emit(everdragons2PfP, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 20)

      expect(await everdragons2PfP.connect(buyer1).claim())
          .to.emit(everdragons2PfP, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 21)
          .to.emit(everdragons2PfP, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 30)

      expect(await everdragons2PfP.connect(buyer1).claim())
          .to.emit(everdragons2PfP, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 31)
          .to.emit(everdragons2PfP, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 40)

      expect(await everdragons2PfP.connect(buyer1).claim())
          .to.emit(everdragons2PfP, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 41)
          .to.emit(everdragons2PfP, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 50)

      expect(await everdragons2PfP.connect(buyer1).claim())
          .to.emit(everdragons2PfP, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 51)
          .to.emit(everdragons2PfP, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 60)

      expect(await everdragons2PfP.balanceOf(buyer1.address)).equal(50);

      await everdragons2PfP.connect(buyer1).claim();
      expect(await everdragons2PfP.balanceOf(buyer1.address)).equal(60);

      await everdragons2PfP.connect(buyer1).claim();
      expect(await everdragons2PfP.balanceOf(buyer1.address)).equal(70);

      await everdragons2PfP.connect(buyer1).claim();
      expect(await everdragons2PfP.balanceOf(buyer1.address)).equal(80);

      await everdragons2PfP.connect(buyer1).claim();
      expect(await everdragons2PfP.balanceOf(buyer1.address)).equal(80);

    })


})
