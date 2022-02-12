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

describe("GenesisFarm", async function () {

  let Everdragons2Genesis
  let everdragons2Genesis
  let GenesisFarm
  let genesisFarm
  let owner, wallet, buyer1, buyer2, treasury, member, beneficiary1, beneficiary2,
      whitelisted1, whitelisted2, whitelisted3, whitelisted4

  before(async function () {
    [owner, wallet, buyer1, buyer2, treasury, member, beneficiary1, beneficiary2,
      whitelisted1, whitelisted2, whitelisted3, whitelisted4] = await ethers.getSigners()
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
          .withArgs(ethers.constants.AddressZero, buyer1.address, 11)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 12)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, buyer1.address, 13)

      expect(await genesisFarm.nextTokenId()).equal(14)
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
      await genesisFarm.connect(treasury).buyTokens(4, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(4)
      })
      await assertThrowsMessage(genesisFarm.connect(buyer1).buyTokens(3, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(3)
      }), 'Not enough tokens left')

      await genesisFarm.connect(treasury).buyTokens(2, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(2)
      })

      await assertThrowsMessage(genesisFarm.connect(buyer1).buyTokens(3, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(3)
      }), 'Not enough tokens left')

    })

  })

  describe('#claimWhitelistedTokens', async function () {

    beforeEach(async function () {
      await initAndDeploy()
      await increaseBlockTimestampBy(11)
    })

    it("should throw if sale not ended yet", async function () {

      await assertThrowsMessage(
          genesisFarm.claimWhitelistedTokens([6], []),
          'Root not set yet')
    })

  })

  describe('#claimWhitelistedTokens', async function () {

    let leaves = []
    let tree
    let root

    before(async function () {
      await initAndDeploy()
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
        leaves[i] = await genesisFarm.encodeLeaf(whitelist[i].address, whitelist[i].tokenIds)
      }
      tree = new MerkleTree(leaves, keccak256, {sort: true})
      root = tree.getHexRoot()
    })

    beforeEach(async function () {
      await initAndDeploy()
      await increaseBlockTimestampBy(11)
      await genesisFarm.setRoot(root)
    })


    it("should allow whitelisted1 to claim 2 dragons", async function () {
      const leaf = leaves[0]
      const proof = tree.getHexProof(leaf)
      await expect(await genesisFarm.connect(whitelisted1).claimWhitelistedTokens([6, 3], proof))
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, whitelisted1.address, 6)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, whitelisted1.address, 3)
    })

    it("should allow whitelisted2 and 3 to claim 4 dragons", async function () {
      let leaf = leaves[1]
      let proof = tree.getHexProof(leaf)
      await genesisFarm.connect(whitelisted2).claimWhitelistedTokens([2], proof)
      leaf = leaves[2]
      proof = tree.getHexProof(leaf)
      await genesisFarm.connect(whitelisted3).claimWhitelistedTokens([8, 7, 1], proof)
    })

    it("should throw if wrong proof", async function () {
      let leaf = leaves[0]
      let proof = tree.getHexProof(leaf)

      await assertThrowsMessage(
          genesisFarm.connect(whitelisted2).claimWhitelistedTokens([2], proof),
          'Invalid proof')
    })

    it("should throw if repeating the claim", async function () {
      let leaf = leaves[1]
      let proof = tree.getHexProof(leaf)
      await genesisFarm.connect(whitelisted2).claimWhitelistedTokens([2], proof)

      await assertThrowsMessage(
          genesisFarm.connect(whitelisted2).claimWhitelistedTokens([2], proof),
          'token already minted')
    })

  })

  describe('#claimRemainingTokens', async function () {

    beforeEach(async function () {
      await initAndDeploy()
      await increaseBlockTimestampBy(11)
    })

    it("should throw if sale not ended yet", async function () {

      await assertThrowsMessage(
          genesisFarm.claimRemainingTokens(treasury.address, 20),
          'Claiming not ended yet')
    })
  })

  describe('#claimRemainingTokens', async function () {

    beforeEach(async function () {
      await initAndDeploy()
      await increaseBlockTimestampBy(11)
      await genesisFarm.connect(buyer1).buyTokens(25, {
        value: ethers.BigNumber.from(await genesisFarm.price()).mul(25)
      })
      let whitelist = [
        {
          address: whitelisted1.address,
          tokenIds: [6, 3]
        },
        {
          address: whitelisted2.address,
          tokenIds: [7]
        },
        {
          address: whitelisted3.address,
          tokenIds: [2, 8, 1]
        },
        {
          address: whitelisted4.address,
          tokenIds: [4, 5]
        }
      ]
      let leaves = []
      for (let i = 0; i < whitelist.length; i++) {
        leaves[i] = await genesisFarm.encodeLeaf(whitelist[i].address, whitelist[i].tokenIds)
      }
      let tree = new MerkleTree(leaves, keccak256, {sort: true})
      let root = tree.getHexRoot()
      await increaseBlockTimestampBy(11)
      await genesisFarm.setRoot(root)
      let leaf = leaves[0]
      let proof = tree.getHexProof(leaf)
      await genesisFarm.connect(whitelisted1).claimWhitelistedTokens([6, 3], proof)
      leaf = leaves[1]
      proof = tree.getHexProof(leaf)
      await genesisFarm.connect(whitelisted2).claimWhitelistedTokens([7], proof)
      await genesisFarm.endClaiming()
    })

    it("should give treasury tokens 1, 2, 4, 5 and 8", async function () {

      await expect(await genesisFarm.claimRemainingTokens(treasury.address, 5))
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, treasury.address, 1)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, treasury.address, 2)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, treasury.address, 4)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, treasury.address, 5)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, treasury.address, 8)

    })

    it("should give treasury tokens 1, 2, 4 and later 5, 8 and 9", async function () {

      await expect(await genesisFarm.claimRemainingTokens(treasury.address, 3))
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, treasury.address, 1)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, treasury.address, 2)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, treasury.address, 4)
      await expect(await genesisFarm.claimRemainingTokens(treasury.address, 3))
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, treasury.address, 5)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, treasury.address, 8)
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, treasury.address, 9)

    })

    it("should give treasury tokens 1, 2, 4, 5, 8, 9 and 10", async function () {

      await expect(await genesisFarm.claimRemainingTokens(treasury.address, 10))
          .to.emit(everdragons2Genesis, 'Transfer')
          .withArgs(ethers.constants.AddressZero, treasury.address, 10)

      expect(await everdragons2Genesis.balanceOf(treasury.address)).equal(7)
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

      await genesisFarm.withdrawProceeds(beneficiary1.address, normalize(4))
      let balance1After = await ethers.provider.getBalance(beneficiary1.address)
      assert.equal(balance1After.sub(balance1Before).toString(), normalize(4))

      await genesisFarm.withdrawProceeds(beneficiary2.address, normalize(220))
      let balance2After = await ethers.provider.getBalance(beneficiary2.address)
      assert.equal(balance2After.sub(balance2Before).toString(), normalize(220))
    })

    it("should throw if insufficient funds", async function () {

      await genesisFarm.withdrawProceeds(beneficiary1.address, 0)
      await assertThrowsMessage(
          genesisFarm.withdrawProceeds(beneficiary2.address, normalize(20)),
          'Insufficient funds')
    })

  })

  describe('test and generate whitelist for Merkle Tree', async function () {

    it("should generate the leaves", async function () {
      await initAndDeploy()
      let whitelist = require('./fixtures/whitelist.json')
      let leaves = []
      for (let i = 0; i < whitelist.length; i++) {
        leaves[i] = await genesisFarm.encodeLeaf(whitelist[i].address, whitelist[i].tokenIds)
      }
      await fs.writeFile(path.resolve(__dirname, 'fixtures/leaves.json'), JSON.stringify(leaves, null, 2))
      let tree = new MerkleTree(leaves, keccak256, {sort: true})
      let root = tree.getHexRoot()
      await increaseBlockTimestampBy(11)
      await genesisFarm.setRoot(root)
      let leaf = leaves[0]
      let proof = tree.getHexProof(leaf)
      expect(proof.length).equal(9)
    })
  })
})
