const {assert} = require("chai");

const Helpers = {

  initEthers(ethers) {
    this.ethers = ethers
  },

  async assertThrowsMessage(promise, message) {
    let notThrowing
    try {
      await promise
      notThrowing = true
      throw new Error('Not throwing')
    } catch (e) {
      const rightMessage = e.message.indexOf(message) > -1
      if (notThrowing) {
        console.log('Not throwing')
      } else if (!rightMessage) {
        console.error('Expected:', message)
        console.error('Returned:', e.message)
      }
      assert.isTrue(rightMessage)
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

  async increaseBlockTimestampBy(offset) {
    await this.ethers.provider.send("evm_increaseTime", [offset])
    await this.ethers.provider.send('evm_mine')
  },

  normalize(val, n = 18) {
    return ('' + val + '0'.repeat(n))
  }

}

module.exports = Helpers
