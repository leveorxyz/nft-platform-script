import { ethers } from "hardhat";
import { writeFile } from "fs/promises";
import { ContractTransaction } from "ethers";
import dotenv from "dotenv";
import {
  Facade,
  Facade__factory,
  Marketplace,
  Marketplace__factory,
  NFT,
  NFT__factory,
} from "../typechain";

dotenv.config();

async function main() {
  let Marketplace: Marketplace__factory,
    marketplace: Marketplace,
    NFT: NFT__factory,
    nft: NFT,
    Facade: Facade__factory,
    facade: Facade;
  const {
    NETWORK_ADDRESS,
    PLATFORM_ADDRESS,
    PLATFORM_PRIMARY_PERCENTAGE,
    PLATFORM_SECONDARY_PERCENTAGE,
    NETWORK_PRIMARY_PERCENTAGE,
    NETWORK_SECONDARY_PERCENTAGE,
    ARTIST_PRIMARY_PERCENTAGE,
    ARTIST_SECONDARY_PERCENTAGE,
  } = process.env;

  const NFTcontract = await ethers.getContractFactory("NFT");
  nft = await NFTcontract.deploy();

  await nft.deployed();
  const nftAddress = nft.address;

  // Deploy Marketplace Contract
  Marketplace = await ethers.getContractFactory("Marketplace");
  marketplace = await Marketplace.deploy(
    PLATFORM_ADDRESS + "",
    NETWORK_ADDRESS + "",
    Number(PLATFORM_PRIMARY_PERCENTAGE),
    Number(PLATFORM_SECONDARY_PERCENTAGE),
    Number(NETWORK_PRIMARY_PERCENTAGE),
    Number(NETWORK_SECONDARY_PERCENTAGE),
    Number(ARTIST_PRIMARY_PERCENTAGE),
    Number(ARTIST_SECONDARY_PERCENTAGE)
  );
  await marketplace.deployed();
  const marketPlaceAddress = marketplace.address;

  // Deploy Facade Contract
  Facade = await ethers.getContractFactory("Facade");
  facade = await Facade.deploy(nftAddress, marketPlaceAddress);

  await facade.deployed();
  const facadeAddress = facade.address;

  // Configure NFT Caller
  const nftConfigureFacadeTx: ContractTransaction =
    await nft.configureFacadeCaller(facadeAddress);
  await nftConfigureFacadeTx.wait();

  const marketplaceConfigureFacadeTx: ContractTransaction =
    await marketplace.configureFacadeCaller(facadeAddress);
  await marketplaceConfigureFacadeTx.wait();
  let explorerLink: string = "";

  switch (process.env.HARDHAT_NETWORK) {
    case "goerli":
      explorerLink = "https://goerli.etherscan.io/address";
      break;
    case "mainnet":
      explorerLink = "https://etherscan.io/address";
      break;
    case "bsctest":
      explorerLink = "https://testnet.bscscan.com/address";
      break;
    case "bscmain":
      explorerLink = "https://bscscan.com/address";
      break;
    case "mumbai":
      explorerLink = "https://mumbai.polygonscan.com/address";
      break;
    case "polygon":
      explorerLink = "https://polygonscan.com/address";
      break;
    case "fuji":
      explorerLink = "https://testnet.avascan.info/blockchain/c/address";
      break;
    case "goerli":
      explorerLink = "https://avascan.info/blockchain/wraptag/address";
      break;
  }
  let nftContractLink = explorerLink + nftAddress,
    marketplaceAddressLink = explorerLink + marketPlaceAddress,
    facadeContractLink = explorerLink + facadeAddress;

  // write addresses of the deployed contracts
  await writeFile(
    "./data.json",
    JSON.stringify({
      nftAddress: nftAddress,
      nftContractLink: nftContractLink,
      marketplaceAddress: marketPlaceAddress,
      marketplaceAddressLink: marketplaceAddressLink,
      facadeAddress: facadeAddress,
      facadeContractLink: facadeContractLink,
    })
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
