const {assert} = require("chai");

const Helpers = {

  initEthers(ethers) {
    this.ethers = ethers
  },

  async assertThrowsMessage(promise, message, showError) {
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
  },

  async signPackedData(
      hash,
      // hardhat account #4, starting from #0
      privateKey = '0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a'
  ) {
    const signingKey = new this.ethers.utils.SigningKey(privateKey)
    const signedDigest = signingKey.signDigest(hash)
    return this.ethers.utils.joinSignature(signedDigest)
  },

  async getTimestamp() {
    return (await this.ethers.provider.getBlock()).timestamp
  },

  addr0: '0x0000000000000000000000000000000000000000',

  async increaseBlockTimestampBy(offset) {
    await this.ethers.provider.send("evm_increaseTime", [offset])
    await this.ethers.provider.send('evm_mine')
  }

}

module.exports = Helpers
