const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

describe("EverDragons2", function () {

  let EverDragons2
  let everDragons2
  let DragonsFarm
  let dragonsFarm
  let PlayerMock
  let playerMock

  let addr0 = '0x0000000000000000000000000000000000000000'
  let owner, teamMember, validator, collector1, collector2, edOwner1, edOwner2

  before(async function () {
    [owner, teamMember, validator, collector1, collector2, edOwner1, edOwner2] = await ethers.getSigners()
  })

  beforeEach(async function () {
    EverDragons2 = await ethers.getContractFactory("EverDragons2")
    // everDragons2 = await EverDragons2.deploy(10001, false)
    everDragons2 = await upgrades.deployProxy(EverDragons2, [10001, false]);
    await everDragons2.deployed()
    DragonsFarm = await ethers.getContractFactory("DragonsFarmMock")
    dragonsFarm = await DragonsFarm.deploy(everDragons2.address)
    await dragonsFarm.deployed()
    await everDragons2.setManager(dragonsFarm.address)
    PlayerMock =  await ethers.getContractFactory("GameMock")
    playerMock = await upgrades.deployProxy(PlayerMock)
    await playerMock.deployed()
  })

  it("should return the EverDragons2 name and symbol", async function () {
    expect(await everDragons2.name()).to.equal("Everdragons2 Genesis Token")
    expect(await everDragons2.symbol()).to.equal("E2GT")
    expect(await everDragons2.manager()).to.equal(dragonsFarm.address)
    expect(await everDragons2.ownerOf(10001)).to.equal(owner.address)

    // console.log(await everDragons2.getInterfaceId())
  })

  it("should mint token 23, 100 and 3230 and give them to collector1", async function () {

    const tokenIds = [23, 100, 3230]

    await expect(dragonsFarm['mint(address,uint256[])'](collector1.address, tokenIds))
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

    await expect(dragonsFarm['mint(address[],uint256[])']([collector1.address, collector2.address, collector1.address,], tokenIds))
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
    await expect(dragonsFarm['mint(address,uint256[])'](collector1.address, tokenIds))
        .revertedWith('Minting ended or not allowed')
  })

  it("should not mint if secondary token", async function () {

    // everDragons2 = await EverDragons2.deploy(10001, true)
    let everDragons2 = await upgrades.deployProxy(EverDragons2, [10001, true]);
    await everDragons2.deployed()
    DragonsFarm = await ethers.getContractFactory("DragonsFarmMock")
    let dragonsFarm = await DragonsFarm.deploy(everDragons2.address)
    await dragonsFarm.deployed()
    await assertThrowsMessage(
        everDragons2.setManager(dragonsFarm.address),
        'Minting ended or not allowed')
  })

  it("should mint token and verify that the player is not initiated", async function () {
    const tokenIds = [1]
    await dragonsFarm['mint(address,uint256[])'](collector1.address, tokenIds)
    expect(await everDragons2.ownerOf(1)).to.equal(collector1.address)

    const attributes = await everDragons2.attributesOf(collector1.address, playerMock.address)
    expect(attributes.version).to.equal(0)

  })

  it("should allow token collector1 to set a player", async function () {
    const tokenIds = [1]
    await dragonsFarm['mint(address,uint256[])'](collector1.address, tokenIds)
    await everDragons2.connect(collector1).initAttributes(1, playerMock.address)
    await playerMock.fillInitialAttributes(
        everDragons2.address,
        1,
        0, // keeps the existent version
        [1, 5, 34, 21, 8, 0, 34, 12, 31, 65, 178, 243, 2]
    )

    const attributes = await everDragons2.attributesOf(1, playerMock.address)
    expect(attributes.version).to.equal(1)
    expect(attributes.attributes[2]).to.equal(34)

  })

  it("should update the levels in PlayerMock", async function () {

    const tokenIds = [1]
    await dragonsFarm['mint(address,uint256[])'](collector1.address, tokenIds)

    await everDragons2.connect(collector1).initAttributes(1, playerMock.address)
    await playerMock.fillInitialAttributes(
        everDragons2.address,
        1,
        0, // keeps the existent version
        [1, 5, 34, 21, 8, 0, 34, 12, 31, 65, 178, 243, 2]
    )

    let attributes = await everDragons2.attributesOf(1, playerMock.address)
    let levelIndex = 3
    expect(attributes.attributes[levelIndex]).to.equal(21)

    await playerMock.levelUp(
        everDragons2.address,
        1,
        levelIndex,
        63
    )

    attributes = await everDragons2.attributesOf(1, playerMock.address)
    expect(attributes.attributes[levelIndex]).to.equal(63)

  })

  it("should check if nft is playable", async function () {

    assert.isTrue(await everDragons2.supportsInterface('0xac517b2e'))

  })

})
