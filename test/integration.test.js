// const {expect, assert} = require("chai")
// const _ = require('lodash')
//
// const {initEthers, assertThrowsMessage, signPackedData, getTimestamp, increaseBlockTimestampBy} = require('./helpers')
//
// describe("Integration test", function () {
//
//   let EverDragons2
//   let everDragons2
//   let DragonsFarm
//   let dragonsFarm
//   let conf
//
//   let addr0 = '0x0000000000000000000000000000000000000000'
//   let owner,
//       edo, ed2, ndl,
//       validator, dao,
//       buyer1, buyer2,
//       member1, member2,
//       collector1, collector2,
//       addr2, addr3, addr4, addr5, addr6, addr7, addr8, addr9, addr10
//
//   before(async function () {
//     ;[
//       owner,
//       edo, ed2, ndl,
//       validator, // << validator is hardhat#4 — Do not change it
//       dao,
//       buyer1, buyer2,
//       member1, member2,
//       collector1, collector2,
//       addr2, addr3, addr4, addr5, addr6, addr7, addr8, addr9, addr10
//     ] = await ethers.getSigners()
//
//     conf = {
//       validator: validator.address,
//       nextTokenId: 1,
//       maxTokenIdForSale: 100,
//       maxPrice: 50 * 100, // = 50 MATIC
//       decrementPercentage: 10, // 10%
//       minutesBetweenDecrements: 10, // 10 minutes
//       numberOfSteps: 5,
//       edOnEthereum: 10,
//       edOnPoa: 5,
//       edOnTron: 5,
//       maxTokenPerWhitelistedWallet: 3
//     }
//     initEthers(ethers)
//   })
//
//   async function initAndDeploy() {
//     EverDragons2 = await ethers.getContractFactory("EverDragons2")
//     everDragons2 = await EverDragons2.deploy(151, false)
//     await everDragons2.deployed()
//     DragonsFarm = await ethers.getContractFactory("DragonsFarm")
//     dragonsFarm = await DragonsFarm.deploy(everDragons2.address)
//     await dragonsFarm.deployed()
//     everDragons2.setManager(dragonsFarm.address)
//
//     conf.startingTimestamp = (await getTimestamp()) + 3600
//     await dragonsFarm.init(
//         conf,
//         edo.address,
//         ed2.address,
//         dao.address,
//         ndl.address
//     )
//   }
//
//   it ('should do the entire flow', async function () {
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       expect(await dragonsFarm.connect(buyer1).buyTokens(3, {
//         value: ethers.BigNumber.from(await dragonsFarm.currentPrice(0)).mul(3)
//       }))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, buyer1.address, 1)
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, buyer1.address, 2)
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, buyer1.address, 3)
//
//
//       await expect(await dragonsFarm.addWalletsToWhitelists([member1.address, member2.address], 2))
//           .to.emit(dragonsFarm, 'WalletWhitelistedForDiscount')
//           .withArgs(member1.address, 2)
//
//       const cost = ethers.BigNumber.from(await dragonsFarm.currentPrice(2)).mul(3)
//       expect(await dragonsFarm.connect(member1).buyDiscountedTokens(2, {
//         value: ethers.BigNumber.from(await dragonsFarm.currentPrice(2)).mul(2)
//       }))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, member1.address, 1)
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, member1.address, 2)
//
//       expect(await dragonsFarm.connect(member2).buyDiscountedTokens(3, {
//         value: ethers.BigNumber.from(await dragonsFarm.currentPrice(2)).mul(3)
//       }))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, member2.address, 3)
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, member2.address, 4)
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, member2.address, 5)
//
//
//       const cost = ethers.BigNumber.from(await dragonsFarm.currentPrice(2)).mul(3)
//       expect(await dragonsFarm.connect(member1).buyDiscountedTokens(2, {
//         value: ethers.BigNumber.from(await dragonsFarm.currentPrice(2)).mul(2)
//       }))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, member1.address, 1)
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, member1.address, 2)
//
//       expect(await dragonsFarm.connect(member1).buyDiscountedTokens(1, {
//         value: ethers.BigNumber.from(await dragonsFarm.currentPrice(2))
//       }))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, member1.address, 3)
//
//     })
//
//     it("should throw if member1 not whitelisted", async function () {
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       // await dragonsFarm.addWalletsToWhitelists([member1.address, member2.address], 2)
//
//       await assertThrowsMessage(
//           dragonsFarm.connect(member1).buyDiscountedTokens(2, {
//             value: ethers.BigNumber.from(await dragonsFarm.currentPrice(2)).mul(3)
//           }), 'Not whitelisted')
//
//     })
//
//     it("should throw if too many tokens", async function () {
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       await dragonsFarm.addWalletsToWhitelists([member1.address, member2.address], 5)
//
//       await assertThrowsMessage(
//           dragonsFarm.connect(member1).buyDiscountedTokens(4, {
//             value: ethers.BigNumber.from(await dragonsFarm.currentPrice(5)).mul(4)
//           }), 'You are trying to get too many tokens')
//
//     })
//
//     it("should throw if insufficient payment", async function () {
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       await dragonsFarm.addWalletsToWhitelists([member1.address, member2.address], 3)
//
//       await assertThrowsMessage(
//           dragonsFarm.connect(member1).buyDiscountedTokens(3, {
//             value: ethers.BigNumber.from(await dragonsFarm.currentPrice(3)).mul(2)
//           }), 'Insufficient payment')
//
//     })
//
//   })
//
//   describe('#claimTokens', async function () {
//
//     beforeEach(async function () {
//       await initAndDeploy()
//       await configure()
//     })
//
//     it("should throw if sale not started yet", async function () {
//
//       await assertThrowsMessage(
//           dragonsFarm.buyTokens(3, {
//             value: ethers.BigNumber.from(await dragonsFarm.currentPrice(0)).mul(3)
//           }),
//           'Sale not started yet')
//
//     })
//
//     it("should collector1 claim 3 tokens on Ethereum", async function () {
//
//       const ownedTokens = [4, 7, 1]
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       let chainId = await dragonsFarm.getChainId()
//
//       const hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 1, chainId)
//       const signature = await signPackedData(hash)
//
//       const finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + e)
//
//       expect(await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 1, signature))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[0])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[1])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[2])
//
//     })
//
//     it("should collector1 claim 2 tokens on POA", async function () {
//
//       const ownedTokens = [3, 5]
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       let chainId = await dragonsFarm.getChainId()
//
//       const hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 2, chainId)
//       const signature = await signPackedData(hash)
//
//       const finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + conf.edOnEthereum + e)
//
//       expect(await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 2, signature))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[0])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[1])
//
//     })
//
//     it("should collector1 claim 2 tokens on Tron", async function () {
//
//       const ownedTokens = [2, 3, 4, 5]
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       let chainId = await dragonsFarm.getChainId()
//
//       const hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 3, chainId)
//       const signature = await signPackedData(hash)
//
//       const finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + conf.edOnEthereum + conf.edOnPoa + e)
//
//       expect(await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 3, signature))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[0])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[1])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[2])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[3])
//
//     })
//
//
//     it("should collector1 claim tokens on Ethereum, Poa and tron", async function () {
//
//       let ownedTokens = [4, 7, 1]
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       let chainId = await dragonsFarm.getChainId()
//
//       let hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 1, chainId)
//       let signature = await signPackedData(hash)
//
//       let finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + e)
//
//       expect(await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 1, signature))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[0])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[1])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[2])
//
//
//       ownedTokens = [3, 5]
//
//       hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 2, chainId)
//       signature = await signPackedData(hash)
//
//       finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + conf.edOnEthereum + e)
//
//       expect(await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 2, signature))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[0])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[1])
//
//
//       ownedTokens = [2, 3, 4, 5]
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//
//       hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 3, chainId)
//       signature = await signPackedData(hash)
//
//       finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + conf.edOnEthereum + conf.edOnPoa + e)
//
//       expect(await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 3, signature))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[0])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[1])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[2])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[3])
//
//     })
//
//
//     it("should revert if collector1 try to claim tokens out of range", async function () {
//
//       const ownedTokens = [34, 560]
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       const hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 3, 31337)
//       const signature = await signPackedData(hash)
//       await assertThrowsMessage(dragonsFarm.connect(collector1).claimTokens(ownedTokens, 3, signature),
//           'Id out of range')
//
//     })
//
//     it("should throw if trying to claim again", async function () {
//
//       let ownedTokens = [4, 7, 1]
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       let chainId = await dragonsFarm.getChainId()
//
//       let hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 1, chainId)
//       let signature = await signPackedData(hash)
//
//       let finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + e)
//
//       expect(await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 1, signature))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[0])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[1])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, collector1.address, finalIds[2])
//
//       hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 1, 31337)
//       signature = await signPackedData(hash)
//       await assertThrowsMessage(dragonsFarm.connect(collector1).claimTokens(ownedTokens, 1, signature),
//           'token already minted')
//
//     })
//
//   })
//
//   describe('#giveAwayTokens', async function () {
//
//     beforeEach(async function () {
//       await initAndDeploy()
//       await configure()
//     })
//
//     it("should owner give away 2 tokens to community members", async function () {
//
//       const ids = [122, 135]
//       const addresses = [member1.address, member2.address]
//
//       // it works even if sale not started yet
//
//       expect(await dragonsFarm.giveAwayTokens(addresses, ids))
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, member1.address, ids[0])
//           .to.emit(everDragons2, 'Transfer')
//           .withArgs(addr0, member2.address, ids[1])
//
//     })
//
//     it("should throw if collector1 try to claim tokens out of range", async function () {
//
//       const addresses = [member1.address]
//
//       await assertThrowsMessage(dragonsFarm.giveAwayTokens(addresses, [56]),
//           'Id out of range')
//
//       await assertThrowsMessage(dragonsFarm.giveAwayTokens(addresses, [112]),
//           'Id out of range')
//
//       await assertThrowsMessage(dragonsFarm.giveAwayTokens(addresses, [300]),
//           'Id out of range')
//
//     })
//
//     it("should throw if inconsistent length", async function () {
//
//       const addresses = [member1.address, member2.address]
//
//       await assertThrowsMessage(dragonsFarm.giveAwayTokens(addresses, [130]),
//           'Inconsistent lengths')
//
//     })
//   })
//
//   describe('#claimWonTokens', async function () {
//
//     beforeEach(async function () {
//       await initAndDeploy()
//       await configure()
//     })
//
//     it("should member1 get 2 won tokens", async function () {
//
//
//       await expect(await dragonsFarm.addWinnerWalletsToWhitelists([member1.address], [2]))
//           .to.emit(dragonsFarm, 'WinnerWalletWhitelisted')
//           .withArgs(member1.address, 2)
//
//       await dragonsFarm.connect(member1).claimWonTokens()
//
//       const balance = await everDragons2.balanceOf(member1.address)
//       expect(await everDragons2.tokenOfOwnerByIndex(member1.address, 0))
//           .to.be.equal(121)
//       expect(await everDragons2.tokenOfOwnerByIndex(member1.address, 1))
//           .to.be.equal(122)
//
//
//     })
//
//     it("should throw if not a winner", async function () {
//
//       await assertThrowsMessage(dragonsFarm.connect(member1).claimWonTokens(),
//           'Not a winner')
//     })
//
//     it("should skip if re-adding a winner", async function () {
//
//       await dragonsFarm.addWinnerWalletsToWhitelists([member1.address], [2])
//
//       expect(await dragonsFarm.giveawaysWinners(member1.address)).equal(3)
//
//       await dragonsFarm.connect(member1).claimWonTokens()
//
//       expect(await dragonsFarm.giveawaysWinners(member1.address)).equal(1)
//
//       await dragonsFarm.addWinnerWalletsToWhitelists([member1.address], [1])
//
//       expect(await dragonsFarm.giveawaysWinners(member1.address)).equal(1)
//     })
//
//     it("should throw if trying again", async function () {
//
//       await dragonsFarm.addWinnerWalletsToWhitelists([member1.address], [2])
//
//       expect(await dragonsFarm.connect(member1).claimWonTokens())
//
//       await assertThrowsMessage(dragonsFarm.connect(member1).claimWonTokens(),
//           'Tokens already minted')
//     })
//
//
//     it("should throw if inconsistent length", async function () {
//
//       const addresses = [member1.address, member2.address]
//
//       await assertThrowsMessage(dragonsFarm.giveAwayTokens(addresses, [130]),
//           'Inconsistent lengths')
//
//     })
//   })
//
//   describe('#mintUnmintedTokens', async function () {
//
//     beforeEach(async function () {
//       await initAndDeploy()
//       const conf2 = {
//         validator: validator.address,
//         nextTokenId: 1,
//         maxTokenIdForSale: 40,
//         maxPrice: 50 * 100, // = 50 MATIC
//         decrementPercentage: 10, // 10%
//         minutesBetweenDecrements: 10, // 10 minutes
//         numberOfSteps: 5,
//         edOnEthereum: 10,
//         edOnPoa: 5,
//         edOnTron: 5,
//         maxTokenPerWhitelistedWallet: 3
//       }
//
//       await configure(conf2)
//
//     })
//
//     it("should mint unminted tokens", async function () {
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       await dragonsFarm.connect(buyer1).buyTokens(3, {
//         value: ethers.BigNumber.from(await dragonsFarm.currentPrice(0)).mul(3)
//       })
//
//       let ownedTokens = [4, 7, 1]
//
//       let chainId = await dragonsFarm.getChainId()
//
//       let hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 1, chainId)
//       let signature = await signPackedData(hash)
//
//       let finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + e)
//
//       await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 1, signature)
//
//       ownedTokens = [3, 5]
//
//       hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 2, chainId)
//       signature = await signPackedData(hash)
//
//       finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + conf.edOnEthereum + e)
//
//       await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 2, signature)
//
//       ownedTokens = [2, 3, 4, 5]
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//
//       hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 3, chainId)
//       signature = await signPackedData(hash)
//
//       finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + conf.edOnEthereum + conf.edOnPoa + e)
//
//       await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 3, signature)
//
//       expect(await everDragons2.balanceOf(owner.address)).equal(1)
//
//       await assertThrowsMessage(dragonsFarm.mintUnmintedTokens(4),
//           'Mint not ended'
//       )
//
//       await dragonsFarm.endMinting()
//
//       await dragonsFarm.mintUnmintedTokens(4)
//
//       assert.isTrue((await everDragons2.balanceOf(owner.address)).toNumber() > 40)
//
//     })
//
//     it("should throw if buyer1 try to mint 3 tokens with bad balance", async function () {
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       await assertThrowsMessage(dragonsFarm.connect(buyer1).buyTokens(3, {
//         value: ethers.BigNumber.from(await dragonsFarm.currentPrice(0))
//       }), 'Insufficient payment')
//
//     })
//
//   })
//
//   describe('#claimEarnings', async function () {
//
//     beforeEach(async function () {
//       await initAndDeploy()
//       const conf2 = {
//         validator: validator.address,
//         nextTokenId: 1,
//         maxTokenIdForSale: 40,
//         maxPrice: 50 * 100, // = 50 MATIC
//         decrementPercentage: 10, // 10%
//         minutesBetweenDecrements: 10, // 10 minutes
//         numberOfSteps: 5,
//         edOnEthereum: 10,
//         edOnPoa: 5,
//         edOnTron: 5,
//         maxTokenPerWhitelistedWallet: 3
//       }
//       await configure(conf2)
//
//     })
//
//     it("should mint unminted tokens", async function () {
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       await dragonsFarm.connect(buyer1).buyTokens(3, {
//         value: ethers.BigNumber.from(await dragonsFarm.currentPrice(0)).mul(3)
//       })
//
//       let ownedTokens = [4, 7, 1]
//
//       let chainId = await dragonsFarm.getChainId()
//
//       let hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 1, chainId)
//       let signature = await signPackedData(hash)
//
//       let finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + e)
//
//       await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 1, signature)
//
//       ownedTokens = [3, 5]
//
//       hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 2, chainId)
//       signature = await signPackedData(hash)
//
//       finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + conf.edOnEthereum + e)
//
//       await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 2, signature)
//
//       ownedTokens = [2, 3, 4, 5]
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//
//       hash = await dragonsFarm.encodeForSignature(collector1.address, ownedTokens, 3, chainId)
//       signature = await signPackedData(hash)
//
//       finalIds = ownedTokens.map(e => conf.maxTokenIdForSale + conf.edOnEthereum + conf.edOnPoa + e)
//
//       await dragonsFarm.connect(collector1).claimTokens(ownedTokens, 3, signature)
//
//       expect(await everDragons2.balanceOf(owner.address)).equal(1)
//
//       await assertThrowsMessage(dragonsFarm.mintUnmintedTokens(4),
//           'Mint not ended'
//       )
//
//       await dragonsFarm.endMinting()
//
//       await dragonsFarm.mintUnmintedTokens(4)
//
//       assert.isTrue((await everDragons2.balanceOf(owner.address)).toNumber() > 40)
//
//     })
//
//     it("should throw if buyer1 try to mint 3 tokens with bad balance", async function () {
//
//       // start the sale:
//       await increaseBlockTimestampBy(3601)
//
//       await assertThrowsMessage(dragonsFarm.connect(buyer1).buyTokens(3, {
//         value: ethers.BigNumber.from(await dragonsFarm.currentPrice(0))
//       }), 'Insufficient payment')
//
//     })
//
//   })
//
// })
