const {expect, assert} = require("chai")
const _ = require("lodash")
const earners = require("../scripts/lib/goldbits-everdragons2.json")
const {cleanStruct} = require("./helpers")

describe.only("GoldbitsEarnings", async function () {

  let GoldbitsEarnings
  let earnings

  before(async function () {
    GoldbitsEarnings = await ethers.getContractFactory("GoldbitsEarnings")
  })

  async function initAndDeploy(saleStartAt) {
    earnings = await GoldbitsEarnings.deploy()
    await earnings.deployed()
  }

    beforeEach(async function () {
      await initAndDeploy()
    })

    it("save the earners and freeze the contract", async function () {

      let wallets = []
      let data = []
      for (let earner of _.clone(earners)) {
        wallets.push(earner.wallet);
        delete earner.wallet
        data.push(earner)
        if (data.length === 10) {
          await earnings.save(wallets, data)
          for (let j=0;j< data.length;j++) {
            let saved = cleanStruct(await earnings.earnings(wallets[j]))
            expect(saved.goldbits).equal(data[j].goldbits)
          }
          wallets = []
          data = []
        }
      }
      if (data.length > 0) {
        await earnings.save(wallets, data)
        for (let j=0;j< data.length;j++) {
          let saved = cleanStruct(await earnings.earnings(wallets[j]))
          expect(saved.goldbits).equal(data[j].goldbits)
        }
      }

      const extra = {
            "id": 80,
            "goldbits": 28100,
            "totalWins": 17,
            "totalTweets": 1
          }
      await earnings.freeze()
      expect(earnings.save(["0xf4cb8b246e34c3c350b25546b013433b24763ce7"], [extra])).revertedWith("Frozen")

    })
})
