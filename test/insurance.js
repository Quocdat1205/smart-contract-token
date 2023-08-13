const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("Lock", function () {
  async function deployOneYearLockFixture() {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const ONE_GWEI = 1_000_000_000;

    const lockedAmount = ONE_GWEI;
    const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS;

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const Insurance = await ethers.getContractFactory("Insurance");
    const insurance = await Insurance.deploy(
      "0x631Dba1263e9bd9bD80833AB1AFF8Ab61841ee40"
    );

    // console.log(await insurance.address, await insurance.owner(), owner.address);

    return { insurance, unlockTime, lockedAmount, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { insurance, owner } = await loadFixture(deployOneYearLockFixture);
      expect(await insurance.owner()).to.equal(owner.address);
    });
  });
});
