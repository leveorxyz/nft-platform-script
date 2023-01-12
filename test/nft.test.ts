import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers,} from 'hardhat';
import { BigNumber, ContractTransaction, ContractReceipt } from 'ethers'
import { NFT, NFT__factory } from "../typechain";


const provider = ethers.provider;

describe('NFT Contract Test', ()=> {

    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshopt in every test.
    async function deployOnceFixture() {
        let NFT: NFT__factory, nft: NFT, contractOwner: SignerWithAddress, add1: SignerWithAddress, add2: SignerWithAddress, otherAccounts: SignerWithAddress[];

        [contractOwner, add1, add2 , ...otherAccounts] = await ethers.getSigners();
        // Deploy NFT
        NFT  = await ethers.getContractFactory("NFT");
        nft = await NFT.deploy();

        await nft.deployed();

        return {nft, contractOwner, add1, add2, otherAccounts}
    }

    it("Should set the right owner", async () => {

        const { nft, contractOwner, add1, add2, otherAccounts } = await loadFixture(deployOnceFixture);

        expect(await nft.owner()).to.equal(contractOwner.address);
    });

    it("NFT Name and Symbol", async () => {

        const { nft, contractOwner, add1, add2, otherAccounts } = await loadFixture(deployOnceFixture);

        expect(await nft.name()).to.equal("Sample NFT");

        expect(await nft.symbol()).to.equal("NFT");

    });

    it("NFT Revert Function Call", async () => {

        const { nft, contractOwner, add1, add2, otherAccounts } = await loadFixture(deployOnceFixture);

        await expect(nft.connect(add1).configureFacadeCaller(add2.address)).to.be.revertedWith('NFT: Only Contract owner can access !');
        await expect(nft.configureFacadeCaller('0x0000000000000000000000000000000000000000')).to.be.revertedWith('NFT: Invalid Facade Contract Address!');

        await expect(nft.connect(add1).safeMint(1, add2.address, "art")).to.be.revertedWith('NFT: Unauthorized Access!');
    });


});