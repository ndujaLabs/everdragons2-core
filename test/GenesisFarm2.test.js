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

describe("GenesisFarm2", async function () {

  let Everdragons2Genesis
  let everdragons2Genesis
  let GenesisFarm
  let genesisFarm
  let GenesisFarm2
  let genesisFarm2
  let owner, wallet, buyer1, buyer2, buyer3, member, beneficiary1, beneficiary2,
      whitelisted1, whitelisted2, whitelisted3, whitelisted4

  before(async function () {
    [owner, wallet, buyer1, buyer2, buyer3, member, beneficiary1, beneficiary2,
      whitelisted1, whitelisted2, whitelisted3, whitelisted4] = await ethers.getSigners()
    Everdragons2Genesis = await ethers.getContractFactory("Everdragons2Genesis")
    GenesisFarm = await ethers.getContractFactory("GenesisFarm")
    GenesisFarm2 = await ethers.getContractFactory("GenesisFarm2")
    initEthers(ethers)
  })

  async function initAndDeploy(saleStartAt) {
    if (!saleStartAt) {
      saleStartAt = (await getTimestamp()) + 10
    }
    everdragons2Genesis = await upgrades.deployProxy(Everdragons2Genesis, []);
    await everdragons2Genesis.deployed()
    genesisFarm = await GenesisFarm.deploy(
        everdragons2Genesis.address,
        25, // maxForSale
        10, // maxClaimable
        normalize(10), // price in MATIC
        saleStartAt)
    await genesisFarm.deployed()
    await everdragons2Genesis.setManager(genesisFarm.address)
  }

  describe.only('#integration test', async function () {

    beforeEach(async function () {
      await initAndDeploy()
      await increaseBlockTimestampBy(11)
    })

    it("should replace the previous manager and manage the sale correctly", async function () {

      await genesisFarm.connect(buyer1).buyTokens(7, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(7)
      })
      await genesisFarm.connect(buyer2).buyTokens(3, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(3)
      })
      await genesisFarm.connect(buyer3).buyTokens(4, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(4)
      })

      expect(await everdragons2Genesis.totalSupply()).equal(14)

      genesisFarm2 = await GenesisFarm2.deploy(
          everdragons2Genesis.address,
          100, // maxForSale
          10, // maxClaimable
          normalize(2),
          4
      )
      await genesisFarm2.deployed()
      await everdragons2Genesis.setManager(genesisFarm2.address)

      expect(await everdragons2Genesis.manager()).equal(genesisFarm2.address)
      expect(await genesisFarm2.maxForSale()).equal(100)
      expect(await genesisFarm2.price()).equal(normalize(2))

      await genesisFarm2.connect(buyer1).buyTokens(3, {
        value: ethers.BigNumber.from(await genesisFarm2.price()).mul(3)
      })

      expect(await everdragons2Genesis.balanceOf(buyer1.address)).equal(10)

      await genesisFarm2.connect(buyer2).buyTokens(30, {
        value: ethers.BigNumber.from(await genesisFarm2.price()).mul(30)
      })

      assertThrowsMessage(genesisFarm.connect(buyer2).buyTokens(3, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(3)
      }), 'Forbidden')

      await genesisFarm2.giveExtraTokens(2)
      expect(await everdragons2Genesis.balanceOf(buyer1.address)).equal(38)
      expect(await everdragons2Genesis.balanceOf(buyer2.address)).equal(45)
      expect(await everdragons2Genesis.balanceOf(buyer3.address)).equal(4)
      expect(await genesisFarm2.extraTokensDistributed()).equal(false)

      await genesisFarm2.giveExtraTokens(2)
      expect(await everdragons2Genesis.balanceOf(buyer1.address)).equal(38)
      expect(await everdragons2Genesis.balanceOf(buyer2.address)).equal(45)
      expect(await everdragons2Genesis.balanceOf(buyer3.address)).equal(20)
      expect(await genesisFarm2.extraTokensDistributed()).equal(true)

      await assertThrowsMessage(genesisFarm2.giveExtraTokens(2), 'All extra tokens have been distributed')

      let proceeds = await genesisFarm2.proceedsBalance()
      let balance1Before = await ethers.provider.getBalance(beneficiary1.address)
      await genesisFarm2.withdrawProceeds(beneficiary1.address, 0)
      expect(await genesisFarm2.proceedsBalance()).equal(0)
      let balance1After = await ethers.provider.getBalance(beneficiary1.address)
      expect(balance1After).equal(balance1Before.add(proceeds).toString())

    })

  })
})
