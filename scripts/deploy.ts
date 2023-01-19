import { ethers } from "hardhat";
import { writeFile } from 'fs/promises';
import dotenv from 'dotenv';

dotenv.config();

async function main() {
  const lockedAmount = ethers.utils.parseEther("1");

  const NFT = await ethers.getContractFactory("NFT");
  // const greeting = await Greeting.deploy("Hello world", { value: lockedAmount });
  const nft = await NFT.deploy();

  await nft.deployed();

  console.log("Greeting contract deployed to: ", nft.address);
  // write
  await writeFile('./data.json', JSON.stringify({nftAddress: nft.address}));
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
