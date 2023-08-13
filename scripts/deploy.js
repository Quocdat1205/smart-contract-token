const hre = require("hardhat");

async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = currentTimestampInSeconds + 60;

  const insuranceDeploy = hre.ethers.utils.parseEther("0.001");

  const InsuranceContract = await hre.ethers.getContractFactory("Insurance");
  const deploy = await InsuranceContract.deploy(unlockTime, { value: insuranceDeploy });

  await deploy.deployed();

  console.log(`Contract deployed to ${deploy.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
