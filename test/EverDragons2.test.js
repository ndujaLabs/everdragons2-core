const { expect, assert } = require("chai")

describe("EverDragons2", function() {

  let EverDragons2
  let everDragons2
  let DragonsMaster
  let dragonMaster

  let addr0 = '0x0000000000000000000000000000000000000000'
  let owner, teamMember1, teamMember2, validator, collector1, collector2, edOwner1, edOwner2

  async function getSignature(address, tokenId, tokenURI) {
    const hash = await everDragons2.encodeForSignature(address, tokenId, tokenURI)
    const signingKey = new ethers.utils.SigningKey('0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d')
    const signedDigest = signingKey.signDigest(hash)
    return ethers.utils.joinSignature(signedDigest)
  }

  async function assertThrowsMessage(promise, message, showError) {
    try {
      await promise
      assert.isTrue(false)
      console.error('This did not throw: ', message)
    } catch (e) {
      if (showError) {
        console.error('Expected: ', message)
        console.error(e.message)
      }
      assert.isTrue(e.message.indexOf(message) > -1)
    }
  }

  before(async function () {
    [owner, teamMember1, teamMember2, validator, collector1, collector2, edOwner1, edOwner2] = await ethers.getSigners()
  })

  beforeEach(async function () {
    EverDragons2 = await ethers.getContractFactory("EverDragons2")
    everDragons2 = await EverDragons2.deploy()
    await everDragons2.deployed()
    DragonsMaster = await ethers.getContractFactory("DragonsMaster")
    dragonMaster = await DragonsMaster.deploy(everDragons2.address)
    await dragonMaster.deployed()
    everDragons2.setManager(dragonMaster.address)
  })

  it("should return the EverDragons2 name and symbol", async function() {
    expect(await everDragons2.name()).to.equal("EverDragons2")
    expect(await everDragons2.symbol()).to.equal("ED2")
    expect(await everDragons2.manager()).to.equal(dragonMaster.address)
    expect(await everDragons2.ownerOf(10001)).to.equal(owner.address)
  })
  //
  // it("should mint token #23", async function() {
  //
  //   const tokenId = 23
  //   const tokenUri = 'ipfs://QmZ5bK81zLneKyV6KUYVGc9WAfVzBeCGTbRTGFQwHLXCfz'
  //
  //   let signature = await getSignature(bob.address, tokenId, tokenUri)
  //
  //   await expect(everDragons2.connect(bob).claimToken(tokenId, tokenUri, signature))
  //       .to.emit(everDragons2, 'Transfer')
  //       .withArgs(addr0, bob.address, tokenId);
  //
  // })
  //
  //
  // it("should throw if signature is wrong", async function() {
  //
  //   const tokenId = 23
  //   const tokenUri = 'ipfs://QmZ5bK81zLneKyV6KUYVGc9WAfVzBeCGTbRTGFQwHLXCfz'
  //
  //   let signature = await getSignature(bob.address, tokenId, tokenUri)
  //
  //   await assertThrowsMessage(
  //       everDragons2.connect(bob).claimToken(24, tokenUri, signature),
  //       'Invalid signature')
  //
  //   await assertThrowsMessage(
  //       everDragons2.connect(alice).claimToken(tokenId, tokenUri, signature),
  //       'Invalid signature')
  //
  //   const hash = await everDragons2.encodeForSignature(bob.address, tokenId, tokenUri)
  //   const signingKey = new ethers.utils.SigningKey(
  //       // bob private key
  //       '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a')
  //   const signedDigest = signingKey.signDigest(hash)
  //   signature = ethers.utils.joinSignature(signedDigest)
  //
  //   await assertThrowsMessage(
  //       everDragons2.connect(bob).claimToken(tokenId, tokenUri, signature),
  //       'Invalid signature')
  //
  // })

})
