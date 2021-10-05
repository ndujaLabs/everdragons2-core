const {expect, assert} = require("chai")

const {initEthers, assertThrowsMessage, signPackedData, getTimestamp, increaseBlockTimestampBy} = require('./helpers')

describe("DragonsMaster", function () {

  let EverDragons
  let everDragons
  let EverDragons2
  let everDragons2
  let DragonsMaster
  let dragonsMaster
  let conf

  let addr0 = '0x0000000000000000000000000000000000000000'
  let owner,
      edo, ed2, ndl,
      validator,
      buyer1, buyer2,
      communityMenber1, communityMenber2,
      collector1, collector2,
      bridge1, bridge2

  before(async function () {
    ;[
      owner,
      edo, ed2, ndl,
      validator,
      buyer1, buyer2,
      communityMenber1, communityMenber2,
      collector1, collector2,
      bridge1, bridge2
    ] = await ethers.getSigners()

    conf = {
      validator: validator.address,
      nextTokenId: 1,
      maxBuyableTokenId: 8800,
      maxPrice: 180, // = 1.8 ETH
      decrementPercentage: 10, // 10%
      minutesBetweenDecrements: 60, // 1 hour
      numberOfSteps: 32
    }
    initEthers(ethers)
  })

  async function initAndDeploy() {
    EverDragons = await ethers.getContractFactory("EverDragonsERC721TokenMock")
    everDragons = await EverDragons.deploy()
    await everDragons.deployed()
    EverDragons2 = await ethers.getContractFactory("EverDragons2")
    everDragons2 = await EverDragons2.deploy()
    await everDragons2.deployed()
    DragonsMaster = await ethers.getContractFactory("DragonsMaster")
    dragonsMaster = await DragonsMaster.deploy(everDragons2.address, everDragons.address)
    await dragonsMaster.deployed()
    everDragons2.setManager(dragonsMaster.address)
  }

  async function configure(conf_ = conf, offset = 3600) {
    conf_.startingTimestamp = (await getTimestamp()) + offset
    await dragonsMaster.init(
        conf_,
        edo.address,
        ed2.address,
        ndl.address,
        bridge1.address,
        bridge2.address
    )
  }

  describe('constructor and initialization', async function () {

    beforeEach(async function () {
      await initAndDeploy()
    })


    it("should return the EverDragons2 address", async function () {
      expect(await dragonsMaster.everDragons2()).to.equal(everDragons2.address)
    })

    it("should initialize the farm", async function () {
      await configure()
      let conf1 = await dragonsMaster.conf()
      for (let key in conf) {
        expect(conf1[key]).to.equal(conf[key])
      }
    })

  })

  describe('#currentStep & #currentPrice', async function () {

    beforeEach(async function () {
      await initAndDeploy()
      await configure()
    })


    it("should return the current price", async function () {

      // sale not started yet
      await assertThrowsMessage(dragonsMaster.currentStep(0), 'Sale not started yet')

      const ts = await getTimestamp()
      // 1 hour passes, sale starts
      await increaseBlockTimestampBy(3601)

      expect(await getTimestamp()).greaterThan((await dragonsMaster.conf()).startingTimestamp)

      let price = await await dragonsMaster.currentStep(0)
      expect(price).to.equal(0)

      expect(await dragonsMaster.currentPrice(price)).to.equal(
          ethers.utils.parseEther((conf.maxPrice / 100).toString())
      )

      // 2 hours have passed, second step
      await increaseBlockTimestampBy(3601)

      price = await await dragonsMaster.currentStep(0)
      expect(price).to.equal(1)

      expect(await dragonsMaster.currentPrice(1)).to.equal(
          ethers.utils.parseEther((conf.maxPrice * 90 / 10000).toString())
      )

    })
  })

  describe('#buyTokens & #buyDiscountedTokens', async function () {

    beforeEach(async function () {
      await initAndDeploy()
      await configure()
    })

    it("should throw if sale not started yet", async function () {

      assertThrowsMessage(
          dragonsMaster.buyTokens([0, 0, 0], {
            value: ethers.BigNumber.from(await dragonsMaster.currentPrice(0)).mul(3)
          }),
          'Sale not started yet')

    })

    it("should buyer1 mint 3 tokens if sale started", async function () {

      // start the sale:
      await increaseBlockTimestampBy(3601)

      expect(await dragonsMaster.connect(buyer1).buyTokens([0, 0, 0], {
        value: ethers.BigNumber.from(await dragonsMaster.currentPrice(0)).mul(3)
      }))
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, buyer1.address, 1)
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, buyer1.address, 2)
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, buyer1.address, 3)

    })

    it("should throw if buyer1 try to mint 3 tokens with bad balance", async function () {

      // start the sale:
      await increaseBlockTimestampBy(3601)

      assertThrowsMessage(dragonsMaster.connect(buyer1).buyTokens([0, 0, 0], {
        value: ethers.BigNumber.from(await dragonsMaster.currentPrice(0))
      }), 'Insufficient payment')

    })

    it("should communityMenber1 mint 2 tokens if sale started with a 1 step price", async function () {

      // start the sale:
      await increaseBlockTimestampBy(3601)

      const hash = await dragonsMaster.encodeForSignature(communityMenber1.address, [0, 0], 1, 1)
      const signature = await signPackedData(hash)

      expect(await dragonsMaster.connect(communityMenber1).buyDiscountedTokens([0, 0], 1, signature, {
        value: ethers.BigNumber.from(await dragonsMaster.currentPrice(1)).mul(3)
      }))
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, communityMenber1.address, 1)
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, communityMenber1.address, 2)

    })

  })

  describe('#claimTokens', async function () {

    let tokens1
    let tokens2

    beforeEach(async function () {
      await initAndDeploy()
      await configure()
      tokens1 = []
      tokens2 = []
      let k = 4
      for (let i = 1; i < k; i++) {
        tokens1.push(i)
        await everDragons.mintToken(collector1.address, i)
        assert.equal(await everDragons.ownerOf(i), collector1.address)
      }
      for (let i = k; i < k + 96; i++) {
        tokens2.push(i)
        await everDragons.mintToken(collector2.address, i)
        assert.equal(await everDragons.ownerOf(i), collector2.address)
      }
    })

    it("should throw if sale not started yet", async function () {

      assertThrowsMessage(dragonsMaster.connect(collector1).claimTokens(tokens1),
          'Sale not started yet')

    })

    it("should collector1 claim 3 tokens on Ethereum", async function () {

      // start the sale:
      await increaseBlockTimestampBy(3601)
      const max = conf.maxBuyableTokenId

      expect(await dragonsMaster.connect(collector1).claimTokens(tokens1))
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector1.address, max + 1)
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector1.address, max + 2)
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector1.address, max + 3)
    })

    it("should throw if collector2 tries to claim 96 tokens all together", async function () {

      // start the sale:
      await increaseBlockTimestampBy(3601)
      const max = conf.maxBuyableTokenId

      assertThrowsMessage(dragonsMaster.connect(collector2).claimTokens(tokens2),
          'contract call run out of gas and made the transaction revert'
          )
    })

    it("should allow collector2 to claim 96 tokens in 4 steps", async function () {

      // start the sale:
      await increaseBlockTimestampBy(3601)
      const max = conf.maxBuyableTokenId

      expect(await dragonsMaster.connect(collector2).claimTokens(tokens2.slice(0, 20)))
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector2.address, max + 4)
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector2.address, max + 23)
      expect(await dragonsMaster.connect(collector2).claimTokens(tokens2.slice(20, 40)))
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector2.address, max + 24)
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector2.address, max + 43)
      expect(await dragonsMaster.connect(collector2).claimTokens(tokens2.slice(40, 60)))
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector2.address, max + 44)
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector2.address, max + 63)
      expect(await dragonsMaster.connect(collector2).claimTokens(tokens2.slice(60, 80)))
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector2.address, max + 64)
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector2.address, max + 83)
      expect(await dragonsMaster.connect(collector2).claimTokens(tokens2.slice(80)))
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector2.address, max + 84)
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, collector2.address, max + 96)
    })

  })


  describe('#giveAwayTokens', async function () {

    beforeEach(async function () {
      await initAndDeploy()
      await configure()
    })

    it("should owner give away 2 tokens to community members", async function () {

      const ids = [9910, 9981]
      const addresses = [communityMenber1.address, communityMenber2.address]

      // it works even if sale not started yet

      expect(await dragonsMaster.giveAwayTokens(addresses, ids))
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, communityMenber1.address, ids[0])
          .to.emit(everDragons2, 'Transfer')
          .withArgs(addr0, communityMenber2.address, ids[1])

    })

    it("should throw if collector1 try to claim tokens out of range", async function () {

      const ids = [9690, 9981]
      const addresses = [communityMenber1.address, communityMenber2.address]

      assertThrowsMessage(dragonsMaster.giveAwayTokens(addresses, ids),
          'Id out of range')

    })
  })

})
