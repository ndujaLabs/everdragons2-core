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

describe("GenesisFarm3", async function () {

  let Everdragons2Genesis
  let everdragons2Genesis
  let GenesisFarm
  let genesisFarm
  let GenesisFarm3
  let genesisFarm3
  let EthereumFarm
  let ethereumFarm
  let owner, wallet, buyer1, buyer2, validator, buyer3, member, beneficiary1, beneficiary2, operator, buyer4, whitelisted1, whitelisted2, whitelisted3, whitelisted4

  before(async function () {
    [owner, wallet, buyer1, buyer2, validator, buyer3, member, beneficiary1, beneficiary2, operator, buyer4, whitelisted1, whitelisted2, whitelisted3, whitelisted4] = await ethers.getSigners()

    Everdragons2Genesis = await ethers.getContractFactory("Everdragons2Genesis")
    GenesisFarm = await ethers.getContractFactory("GenesisFarm")
    GenesisFarm3 = await ethers.getContractFactory("GenesisFarm3")
    EthereumFarm = await ethers.getContractFactory("EthereumFarm")
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
        normalize(100), // price in MATIC
        saleStartAt)
    await genesisFarm.deployed()
    await everdragons2Genesis.setManager(genesisFarm.address)
    ethereumFarm = await EthereumFarm.deploy(validator.address)
    await ethereumFarm.deployed()
  }

  describe('#integration test', async function () {

    beforeEach(async function () {
      await initAndDeploy()
      await increaseBlockTimestampBy(11)
    })

    it.only("should verify that the cross chain purchases work", async function () {

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

      genesisFarm3 = await GenesisFarm3.deploy(
          everdragons2Genesis.address,
          100, // maxForSale
          10, // maxClaimable
          ethers.utils.parseEther("0.1"),
          operator.address
      )
      await genesisFarm3.deployed()
      await everdragons2Genesis.setManager(genesisFarm3.address)

      expect(await everdragons2Genesis.manager()).equal(genesisFarm3.address)
      expect(await genesisFarm3.maxForSale()).equal(100)
      expect(await genesisFarm3.price()).equal('100000000000000000')
      expect(await genesisFarm3.operator()).equal(operator.address)

      await genesisFarm3.connect(buyer1).buyTokens(3, {
        value: ethers.BigNumber.from(await genesisFarm3.price()).mul(3)
      })

      expect(await everdragons2Genesis.balanceOf(buyer1.address)).equal(10)



      // 0.06 ETH
      const ethPrice = ethers.BigNumber.from(6 + '0'.repeat(16))

      let nonce = 1
      let quantity = 2

      let cost = ethPrice.mul(quantity)

      let hash = await ethereumFarm.encodeForSignature(buyer4.address, quantity , nonce, cost)

      let signature = await signPackedData(hash)

      await expect(await ethereumFarm.connect(buyer4).buyTokenCrossChain(quantity, nonce, cost, signature, {
        value: cost
      }))
          .emit(ethereumFarm, 'CrossChainPurchase')
          .withArgs(nonce)

      await assertThrowsMessage(ethereumFarm.connect(buyer4).buyTokenCrossChain(quantity, nonce, cost, signature), "Nonce already used")

      const {buyer, quantity: amount} = await ethereumFarm.purchasedTokens(nonce)
      assert.equal(buyer, buyer4.address)

      await genesisFarm3.connect(operator).deliverCrossChainPurchase(nonce, buyer, amount)

      expect(await everdragons2Genesis.balanceOf(buyer)).equal(amount)
      await genesisFarm3.connect(buyer1).buyTokens(3, {
        value: ethers.BigNumber.from(await genesisFarm3.price()).mul(3)
      })
      expect(await everdragons2Genesis.balanceOf(buyer1.address)).equal(13)

      quantity = 1
      nonce++

      cost = ethPrice

      hash = await ethereumFarm.encodeForSignature(buyer2.address, quantity , nonce, cost)
      signature = await signPackedData(hash)

      await expect(await ethereumFarm.connect(buyer2).buyTokenCrossChain(quantity, nonce, cost, signature, {
        value: cost
      }))
          .emit(ethereumFarm, 'CrossChainPurchase')
          .withArgs(nonce)

      const {buyer: buyerB, quantity: amountB} = await ethereumFarm.purchasedTokens(nonce)
      assert.equal(buyerB, buyer2.address)

      expect(await everdragons2Genesis.balanceOf(buyer2.address)).equal(3)
      await genesisFarm3.connect(operator).deliverCrossChainPurchase(nonce, buyerB, amountB)
      expect(await everdragons2Genesis.balanceOf(buyer2.address)).equal(4)

      await assertThrowsMessage(genesisFarm3.connect(operator).deliverCrossChainPurchase(nonce, buyerB, amountB), "Nonce already used")

      let proceeds = await genesisFarm3.proceedsBalance()
      let balance1Before = await ethers.provider.getBalance(beneficiary1.address)
      await genesisFarm3.withdrawProceeds(beneficiary1.address, 0)
      expect(await genesisFarm3.proceedsBalance()).equal(0)
      let balance1After = await ethers.provider.getBalance(beneficiary1.address)
      expect(balance1After).equal(balance1Before.add(proceeds).toString())

      proceeds = await ethereumFarm.proceedsBalance()
      expect(proceeds).equal(ethPrice.mul(3).toString())

      balance1Before = await ethers.provider.getBalance(beneficiary2.address)
      await ethereumFarm.withdrawProceeds(beneficiary2.address, 0)
      expect(await ethereumFarm.proceedsBalance()).equal(0)
      balance1After = await ethers.provider.getBalance(beneficiary2.address)
      expect(balance1After).equal(balance1Before.add(proceeds).toString())

    })

  })

  describe('#claimWhitelistedTokens', async function () {

    let leaves = []
    let tree
    let root

    before(async function () {

      await initAndDeploy()

      genesisFarm3 = await GenesisFarm3.deploy(
          everdragons2Genesis.address,
          100, // maxForSale
          10, // maxClaimable
          ethers.utils.parseEther("0.1"),
          operator.address
      )
      await genesisFarm3.deployed()
      await everdragons2Genesis.setManager(genesisFarm3.address)

      let whitelist = [
        {
          address: whitelisted1.address,
          tokenIds: [6, 3]
        },
        {
          address: whitelisted2.address,
          tokenIds: [2]
        },
        {
          address: whitelisted3.address,
          tokenIds: [8, 7, 1]
        },
        {
          address: whitelisted4.address,
          tokenIds: [4, 5]
        }
      ]
      for (let i = 0; i < whitelist.length; i++) {
        leaves[i] = await genesisFarm3.encodeLeaf(whitelist[i].address, whitelist[i].tokenIds)
      }
      tree = new MerkleTree(leaves, keccak256, {sort: true})
      root = tree.getHexRoot()
    })

    beforeEach(async function () {
      await initAndDeploy()
      await increaseBlockTimestampBy(11)

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

      genesisFarm3 = await GenesisFarm3.deploy(
          everdragons2Genesis.address,
          100, // maxForSale
          10, // maxClaimable
          ethers.utils.parseEther("0.1"),
          operator.address
      )
      await genesisFarm3.deployed()
      await everdragons2Genesis.setManager(genesisFarm3.address)
      await genesisFarm3.setRoot(root)
    })


    it("should allow whitelisted1 to claim 2 dragons", async function () {
      const leaf = leaves[0]
      const proof = tree.getHexProof(leaf)
      await expect(await genesisFarm3.connect(whitelisted1).claimWhitelistedTokens([6, 3], proof))
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, whitelisted1.address, 6)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, whitelisted1.address, 3)
    })

    it("should allow owner to claim 1 dragons for whitelisted2", async function () {
      let leaf = leaves[1]
      let proof = tree.getHexProof(leaf)
      await expect(await genesisFarm3.delegatedClaimWhitelistedTokens(whitelisted2.address, [2], proof))
          .emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, whitelisted2.address, 2)

    })

    it("should allow owner to claim batch dragons for whitelisted1 and 2", async function () {
      let leaf = leaves[0]
      let proof = tree.getHexProof(leaf)
      leaf = leaves[1]
      let proof2 = tree.getHexProof(leaf)
      await expect(await genesisFarm3.batchDelegatedClaimWhitelistedTokens([whitelisted1.address, whitelisted2.address], [[6, 3], [2]], [proof, proof2]))
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, whitelisted1.address, 6)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, whitelisted1.address, 3)
          .emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, whitelisted2.address, 2)

    })


  })
})
