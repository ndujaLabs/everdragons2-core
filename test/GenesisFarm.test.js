const {expect, assert} = require("chai")
const _ = require('lodash')

const {initEthers, assertThrowsMessage, signPackedData, normalize, getTimestamp, increaseBlockTimestampBy} = require('./helpers')

describe("GenesisFarm", function () {

  let Everdragons2Genesis
  let everdragons2Genesis
  let GenesisFarm
  let genesisFarm
  let owner, wallet, buyer1, buyer2, buyer3, member, beneficiary1, beneficiary2

  before(async function () {
    [owner, wallet, buyer1, buyer2, buyer3, member, beneficiary1, beneficiary2] = await ethers.getSigners()
    Everdragons2Genesis = await ethers.getContractFactory("Everdragons2Genesis")
    GenesisFarm = await ethers.getContractFactory("GenesisFarm")
    initEthers(ethers)
  })

  async function initAndDeploy(saleStartAt) {
    if (!saleStartAt) {
      saleStartAt = (await getTimestamp()) + 10
    }
    everdragons2Genesis = await upgrades.deployProxy(Everdragons2Genesis, []);
    await everdragons2Genesis.deployed()
    genesisFarm = await GenesisFarm.deploy(everdragons2Genesis.address, 25, 10, saleStartAt)
    await genesisFarm.deployed()
    await everdragons2Genesis.setManager(genesisFarm.address)
  }

  describe('constructor and initialization', async function () {

    beforeEach(async function () {
      await initAndDeploy()
    })

    it("should return the Everdragons2 address", async function () {
      expect(await genesisFarm.everdragons2Genesis()).equal(everdragons2Genesis.address)
      expect(await genesisFarm.maxForSale()).equal(25)
      expect(await genesisFarm.price()).equal('10000000000000000000')
    })

  })

  describe('#buyTokens', async function () {

    beforeEach(async function () {
      await initAndDeploy()
    })

    it("should throw if sale not started yet", async function () {

      await assertThrowsMessage(
          genesisFarm.buyTokens(3, {
            value: ethers.BigNumber.from(await genesisFarm.price()).mul(3)
          }),
          'Sale not started yet')

    })
  })

  describe('#buyTokens', async function () {

    beforeEach(async function () {
      await initAndDeploy()
      await increaseBlockTimestampBy(11)
    })

    it("should buyer1 mint 3 tokens if sale started", async function () {

      expect(await genesisFarm.connect(buyer1).buyTokens(3, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(3)
      }))
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 1)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 2)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 3)
    })

    it("should throw if buyer1 try to mint 3 tokens with insufficient balance", async function () {

      await assertThrowsMessage(genesisFarm.connect(buyer1).buyTokens(3, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(29).div(10)
      }), 'Insufficient payment')

    })

    it("should throw if sale ended", async function () {

      await genesisFarm.connect(buyer1).buyTokens(10, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(10)
      })
      await genesisFarm.connect(buyer2).buyTokens(9, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(9)
      })
      await genesisFarm.connect(buyer3).buyTokens(4, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(4)
      })
      await assertThrowsMessage(genesisFarm.connect(buyer1).buyTokens(3, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(3)
      }), 'Not enough tokens left')

      await genesisFarm.connect(buyer3).buyTokens(2, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(2)
      })

      await assertThrowsMessage(genesisFarm.connect(buyer1).buyTokens(3, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(3)
      }), 'Not enough tokens left')

    })

  })


  describe('#giveAway350Tokens', async function () {

    beforeEach(async function () {
      await initAndDeploy()
      await increaseBlockTimestampBy(11)
    })

    it("should throw if sale not ended yet", async function () {

      await assertThrowsMessage(
          genesisFarm.giveAway350Tokens([member.address], [26]),
          'Sale not ended yet')

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
      await increaseBlockTimestampBy(11)
      await genesisFarm.connect(buyer1).buyTokens(25, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(25)
      })
    })


    it("should airdrop 350 token to winners", async function () {

      assert.equal((await everdragons2Genesis.totalSupply()).toNumber(), 25)

      // then airdrop to the winners

      for (let i = 0; i < addresses.length; i += 25) {
        let addrs = addresses.slice(i, i + 25)
        let qty = quantities.slice(i, i + 25)
        await genesisFarm.giveAway350Tokens(addrs, qty)
      }
      assert.equal((await everdragons2Genesis.totalSupply()).toNumber(), 375)
    })

    it("should skip double winners", async function () {

      let addrs = addresses.slice(43, 57)
      let qty = quantities.slice(43, 57)

      await genesisFarm.giveAway350Tokens(addrs, qty)

      for (let i = 0; i < addresses.length; i += 25) {
        addrs = addresses.slice(i, i + 25)
        qty = quantities.slice(i, i + 25)
        await genesisFarm.giveAway350Tokens(addrs, qty)
      }
      assert.equal((await everdragons2Genesis.totalSupply()).toNumber(), 375)
    })


  })

  describe('#withdrawProceeds', async function () {

    beforeEach(async function () {
      await initAndDeploy()
      await increaseBlockTimestampBy(11)
      await genesisFarm.connect(buyer1).buyTokens(25, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(25)
      })
    })

    it("should withdraw the proceeds", async function () {

      let balance1Before = await ethers.provider.getBalance(beneficiary1.address)
      let balance2Before = await ethers.provider.getBalance(beneficiary2.address)

      await genesisFarm.withdrawProceeds(beneficiary1.address, normalize(30))
      let balance1After = await ethers.provider.getBalance(beneficiary1.address)
      assert.equal(balance1After.sub(balance1Before).toString(), normalize(30))

      await genesisFarm.withdrawProceeds(beneficiary2.address, normalize(220))
      let balance2After = await ethers.provider.getBalance(beneficiary2.address)
      assert.equal(balance2After.sub(balance2Before).toString(), normalize(220))
    })

    it("should throw if sale not ended yet", async function () {

      await genesisFarm.withdrawProceeds(beneficiary1.address, 0)
      await assertThrowsMessage(
          genesisFarm.withdrawProceeds(beneficiary2.address, normalize(20)),
          'Insufficient funds')

    })

  })

})
