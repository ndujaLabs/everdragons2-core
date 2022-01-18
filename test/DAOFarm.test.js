const {expect, assert} = require("chai")
const _ = require('lodash')

const {initEthers, assertThrowsMessage, signPackedData, getTimestamp, increaseBlockTimestampBy} = require('./helpers')

describe("DAOFarm", function () {

  let Everdragons2
  let everdragons2
  let DAOFarm
  let dAOFarm
  let signers

  before(async function () {
    signers = await ethers.getSigners()
    initEthers(ethers)
  })

  async function initAndDeploy() {
    Everdragons2 = await ethers.getContractFactory("Everdragons2")
    // everdragons2 = await Everdragons2.deploy(151, false)
    everdragons2 = await upgrades.deployProxy(Everdragons2, [10001, false]);
    await everdragons2.deployed()
    DAOFarm = await ethers.getContractFactory("DAOFarm")
    dAOFarm = await DAOFarm.deploy(everdragons2.address)
    await dAOFarm.deployed()
    everdragons2.setManager(dAOFarm.address)
  }

  describe('constructor and initialization', async function () {

    beforeEach(async function () {
      await initAndDeploy()
    })


    it("should return the Everdragons2 address", async function () {
      expect(await dAOFarm.everdragons2()).to.equal(everdragons2.address)
    })

  })

  describe('#mintInitial150Tokens', async function () {

    beforeEach(async function () {
      await initAndDeploy()
    })


    it("should mint 150 token to the owner", async function () {

      // Agdaroth
      assert.equal((await everdragons2.totalSupply()).toNumber(), 1)

      for (let i = 0; i < 150; i += 35) {
        assert.equal((await everdragons2.totalSupply()).toNumber(), 1 + i)
        await dAOFarm.mintInitial150Tokens(35)
      }
      assert.equal((await everdragons2.totalSupply()).toNumber(), 151)
    })


  })

  describe('#giveAway350Tokens', async function () {

    const addresses = []
    const quantities = []
    let total = 0

    before(async function () {
      while (total < 350) {
        let wallet = ethers.Wallet.createRandom().address
        let rand = 100 * Math.random()
        let quantity = rand < 90 ? 1 : rand < 98 ? 2 : 3
        if (total + quantity > 350) {
          quantity = 350 - total
        }
        addresses.push(wallet)
        quantities.push(quantity)
        total += quantity
      }
    })

    beforeEach(async function () {
      await initAndDeploy()
    })


    it("should airdrop 350 token to winners", async function () {

      // first mint the initial 150
      for (let i = 0; i < 150; i += 35) {
        await dAOFarm.mintInitial150Tokens(35)
      }

      assert.equal((await everdragons2.totalSupply()).toNumber(), 151)

      // then airdrop to the winners

      for (let i = 0; i < addresses.length; i += 25) {
        let addrs = addresses.slice(i, i + 25)
        let qty = quantities.slice(i, i + 25)
        await dAOFarm.giveAway350Tokens(addrs, qty)
      }
      assert.equal((await everdragons2.totalSupply()).toNumber(), 501)
    })

    it("should skip double winners", async function () {

      // first mint the initial 150
      for (let i = 0; i < 150; i += 35) {
        await dAOFarm.mintInitial150Tokens(35)
      }

      assert.equal((await everdragons2.totalSupply()).toNumber(), 151)

      // then airdrop to the winners

      let addrs = addresses.slice(43, 57)
      let qty = quantities.slice(43, 57)

      await dAOFarm.giveAway350Tokens(addrs, qty)

      for (let i = 0; i < addresses.length; i += 25) {
        addrs = addresses.slice(i, i + 25)
        qty = quantities.slice(i, i + 25)
        await dAOFarm.giveAway350Tokens(addrs, qty)
      }
      assert.equal((await everdragons2.totalSupply()).toNumber(), 501)
    })


  })

})
