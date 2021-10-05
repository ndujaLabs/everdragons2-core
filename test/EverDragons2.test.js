const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

describe("EverDragons2", function () {

  let EverDragons2
  let everDragons2
  let DragonsMaster
  let dragonsMaster

  let addr0 = '0x0000000000000000000000000000000000000000'
  let owner, teamMember, validator, collector1, collector2, edOwner1, edOwner2

  before(async function () {
    [owner, teamMember, validator, collector1, collector2, edOwner1, edOwner2] = await ethers.getSigners()
  })

  beforeEach(async function () {
    EverDragons2 = await ethers.getContractFactory("EverDragons2")
    everDragons2 = await EverDragons2.deploy()
    await everDragons2.deployed()
    DragonsMaster = await ethers.getContractFactory("DragonsMasterMock")
    dragonsMaster = await DragonsMaster.deploy(everDragons2.address)
    await dragonsMaster.deployed()
    everDragons2.setManager(dragonsMaster.address)
  })

  it("should return the EverDragons2 name and symbol", async function () {
    expect(await everDragons2.name()).to.equal("EverDragons2")
    expect(await everDragons2.symbol()).to.equal("ED2")
    expect(await everDragons2.manager()).to.equal(dragonsMaster.address)
    expect(await everDragons2.ownerOf(10001)).to.equal(owner.address)
  })

  it("should mint token 23, 100 and 3230 and give them to collector1", async function () {

    const tokenIds = [23, 100, 3230]

    await expect(dragonsMaster['mint(address,uint256[])'](collector1.address, tokenIds))
        .to.emit(everDragons2, 'Transfer')
        .withArgs(addr0, collector1.address, tokenIds[0])
        .to.emit(everDragons2, 'Transfer')
        .withArgs(addr0, collector1.address, tokenIds[1])
        .to.emit(everDragons2, 'Transfer')
        .withArgs(addr0, collector1.address, tokenIds[2]);

    expect(await everDragons2.ownerOf(tokenIds[0])).to.equal(collector1.address)
    expect(await everDragons2.tokenOfOwnerByIndex(collector1.address, 0)).to.equal(tokenIds[0])
    expect(await everDragons2.tokenOfOwnerByIndex(collector1.address, 1)).to.equal(tokenIds[1])
    expect(await everDragons2.tokenOfOwnerByIndex(collector1.address, 2)).to.equal(tokenIds[2])

  })

  it("should mint token 23, 100 and 3230 and give two to collector1 and one to collector2", async function () {

    const tokenIds = [23, 100, 3230]

    await expect(dragonsMaster['mint(address[],uint256[])']([collector1.address, collector2.address, collector1.address,], tokenIds))
        .to.emit(everDragons2, 'Transfer')
        .withArgs(addr0, collector1.address, tokenIds[0])
        .to.emit(everDragons2, 'Transfer')
        .withArgs(addr0, collector2.address, tokenIds[1])
        .to.emit(everDragons2, 'Transfer')
        .withArgs(addr0, collector1.address, tokenIds[2])

    expect(await everDragons2.ownerOf(tokenIds[0])).to.equal(collector1.address)
    expect(await everDragons2.ownerOf(tokenIds[1])).to.equal(collector2.address)
    expect(await everDragons2.ownerOf(tokenIds[2])).to.equal(collector1.address)
  })

  it("should throw if dragons master tries to mint when minting is ended", async function () {

    await everDragons2.endMinting()
    const tokenIds = [1, 2, 3, 4]
    await expect(dragonsMaster['mint(address,uint256[])'](collector1.address, tokenIds))
        .revertedWith('Minting ended')
  })

})
