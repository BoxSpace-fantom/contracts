const hre = require("hardhat");

async function main() {

  // Deploy Safe contract
  const Safe = await hre.ethers.getContractFactory("BoxDefi");
  const safe = await Safe.deploy();
  await safe.deployed();
  console.log("contracts deployed to:", safe.address); 
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

//contracts deployed to: 0x4e368562E3A07A08b7cA2f16c649702FbD485932
