const hre = require("hardhat");

async function main() {

  const ewolCampaignRegistryFactory = await hre.ethers.getContractFactory("EwolCampaignRegistry");
  const ewolCampaignRegistryInstance = await ewolCampaignRegistryFactory.deploy("EwolStablecoin", "EWS");

  await ewolCampaignRegistryInstance.deployed();

  console.log(
    `EwolCampaignRegistry deployed to ${ewolCampaignRegistryInstance.address}`
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
