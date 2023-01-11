import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers,} from 'hardhat';
import { BigNumber, ContractTransaction, ContractReceipt } from 'ethers'
import { Facade, Facade__factory, Marketplace, Marketplace__factory, NFT, NFT__factory } from "../typechain";


const provider = ethers.provider;

describe('Facade Marketplace Contract Test', () => {

    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshopt in every test.
    async function deployOnceFixture() {
        let Marketplace: Marketplace__factory, marketplace: Marketplace, NFT: NFT__factory, nft: NFT, Facade: Facade__factory, facade: Facade, platformAddress: SignerWithAddress, networkAddress: SignerWithAddress, contractOwner: SignerWithAddress, add1: SignerWithAddress, add2: SignerWithAddress, add3: SignerWithAddress, add4: SignerWithAddress, add5: SignerWithAddress, otherAccounts: SignerWithAddress[];

        [contractOwner, platformAddress, networkAddress, add1, add2, add3, add4, add5, ...otherAccounts] = await ethers.getSigners();
        // Deploy NFT Contract
        NFT = await ethers.getContractFactory("NFT");
        nft = await NFT.deploy();

        await nft.deployed();

        // Deploy Marketplace Contract
        Marketplace = await ethers.getContractFactory("Marketplace");
        marketplace = await Marketplace.deploy(platformAddress.address, networkAddress.address, 10, 3, 2, 3, 87, 10);

        await marketplace.deployed();

        // Deploy Facade Contract
        Facade = await ethers.getContractFactory("Facade");
        facade = await Facade.deploy(nft.address, marketplace.address);

        await facade.deployed();

        // Configure NFT Caller
        const nftConfigureFacadeTx: ContractTransaction = await nft.connect(contractOwner).configureFacadeCaller(facade.address);
        await nftConfigureFacadeTx.wait();

        const marketplaceConfigureFacadeTx: ContractTransaction = await marketplace.connect(contractOwner).configureFacadeCaller(facade.address);
        await marketplaceConfigureFacadeTx.wait();

        return { nft, marketplace, facade, contractOwner, platformAddress, networkAddress, add1, add2, add3, add4, add5, otherAccounts}
    }

    it("Mint Token", async () => {

        const { nft, marketplace, facade, contractOwner, platformAddress, networkAddress, add1, add2, add3, add4, add5, otherAccounts } = await loadFixture(deployOnceFixture);
        
        const mintTx: ContractTransaction = await facade.connect(contractOwner).mintToken("art", "art", add1.address);
        await mintTx.wait();

        expect(await nft.connect(contractOwner).ownerOf(1)).to.equal(add1.address);
    });

    it("Mint Token with same uri or title Revert Error", async () => {

        const { nft, marketplace, facade, contractOwner, platformAddress, networkAddress, add1, add2, add3, add4, add5, otherAccounts } = await loadFixture(deployOnceFixture);

        const mintTx: ContractTransaction = await facade.connect(contractOwner).mintToken("art", "art", add1.address);
        await mintTx.wait();

        await expect(facade.connect(contractOwner).mintToken("art", "book", add1.address)).to.be.revertedWith("Facade: Token With same uri or title Exist!");
        await expect(facade.connect(contractOwner).mintToken("book", "art", add1.address)).to.be.revertedWith("Facade: Token With same uri or title Exist!");

    });

    it("Get Token Function", async () => {

        const { nft, marketplace, facade, contractOwner, platformAddress, networkAddress, add1, add2, add3, add4, add5, otherAccounts } = await loadFixture(deployOnceFixture);

        const mintTx: ContractTransaction = await facade.connect(contractOwner).mintToken("art", "art", add1.address);
        await mintTx.wait();

        await expect(facade.connect(add1).getToken(0)).to.be.revertedWith("Facade: The Token Doesn't Exist!");

        let tokenDetail = await facade.connect(add1).getToken(1);

        expect(tokenDetail._tokenId).to.equal(1);
        expect(tokenDetail._creator).to.equal(contractOwner.address);
        expect(tokenDetail._currentOwner).to.equal(add1.address);
        expect(tokenDetail._uri).to.equal("art");
        expect(tokenDetail._title).to.equal("art");
    });

    it("Get Total Number of Nft Function", async () => {

        const { nft, marketplace, facade, contractOwner, platformAddress, networkAddress, add1, add2, add3, add4, add5, otherAccounts } = await loadFixture(deployOnceFixture);

        const mintTx1: ContractTransaction = await facade.connect(contractOwner).mintToken("art", "art", add1.address);
        await mintTx1.wait();

        const mintTx2: ContractTransaction = await facade.connect(contractOwner).mintToken("book", "book", add1.address);
        await mintTx2.wait();

        expect(await facade.getTotalNumberOfNft()).to.equal(2);
    });

    it("intialize auction function", async () => {
        
        const { nft, marketplace, facade, contractOwner, platformAddress, networkAddress, add1, add2, add3, add4, add5, otherAccounts } = await loadFixture(deployOnceFixture);

        const mintTx: ContractTransaction = await facade.connect(contractOwner).mintToken("art", "art", add1.address);
        await mintTx.wait();

        await expect(facade.connect(add1).intializeAuction(1, 3000000)).to.be.revertedWith("Facade: Unauthorized Access!");

        const intializeAuctionTx: ContractTransaction = await facade.connect(contractOwner).intializeAuction(1, 3000000);
        const intializeAuctionTxReceipt: ContractReceipt = await intializeAuctionTx.wait();

        const event = intializeAuctionTxReceipt.events?.find(event => event.event === 'AuctionStart');
        const tokenId = event?.args!.tokenId.toNumber();

        expect(tokenId).to.equal(1);

    });

    it('Bid Function', async () => {

        const { nft, marketplace, facade, contractOwner, platformAddress, networkAddress, add1, add2, add3, add4, add5, otherAccounts } = await loadFixture(deployOnceFixture);

        const mintTx: ContractTransaction = await facade.connect(contractOwner).mintToken("art", "art", add1.address);
        await mintTx.wait();

        const intializeAuctionTx: ContractTransaction = await facade.connect(contractOwner).intializeAuction(1, 3000000);
        await intializeAuctionTx.wait();

        //Compulsory Step Token owner should approve facade contract address corresponding token id
        const approve: ContractTransaction = await nft.connect(add1).approve(facade.address, 1);

        await expect(facade.connect(contractOwner).bidAmount(1, add1.address, add2.address, {
            value: ethers.utils.parseEther("0.0")
        })).to.be.revertedWith("Facade: You can't bid with 0 amount!");

        await expect(facade.connect(contractOwner).bidAmount(1, add1.address,add1.address, {
            value: ethers.utils.parseEther("5.0")
        })).to.be.revertedWith("Facade: The token current owner can not bid!");

        await expect(facade.connect(contractOwner).bidAmount(1, add3.address,add2.address, {
            value: ethers.utils.parseEther("5.0")
        })).to.be.revertedWith("Facade: Invalid owner address provided!");

        const beforeBidbalanceofMarketplace: BigNumber = await provider.getBalance(marketplace.address);

        const bidAmountTx: ContractTransaction = await facade.connect(contractOwner).bidAmount(1, add1.address, add2.address, {
            value: ethers.utils.parseEther("5.0")
        });

        await bidAmountTx.wait();

        await expect(facade.connect(contractOwner).bidAmount(1, add1.address, add3.address, {
            value: ethers.utils.parseEther("2.0")
        })).to.be.revertedWith("There already is a higher bid.");

        const afterBidbalanceofMarketplace: BigNumber = await provider.getBalance(marketplace.address);

        const balanceDiffOfNsMarket: number = Number(afterBidbalanceofMarketplace) - Number(beforeBidbalanceofMarketplace);

        expect(balanceDiffOfNsMarket).to.equal(5e18);


    });

    it("end Auction Function for Primary Sale", async () => {

        const { nft, marketplace, facade, contractOwner, platformAddress, networkAddress, add1, add2, add3, add4, add5, otherAccounts } = await loadFixture(deployOnceFixture);


        const mintTx: ContractTransaction = await facade.connect(contractOwner).mintToken("art", "art", add1.address);
        await mintTx.wait();

        const intializeAuctionTx: ContractTransaction = await facade.connect(contractOwner).intializeAuction(1, 3000000);
        await intializeAuctionTx.wait();

        //Compulsory Step Token owner should approve facade contract address corresponding token id
        const approveTx: ContractTransaction = await nft.connect(add1).approve(facade.address, 1);
        await approveTx.wait();

        const bidAmountTx: ContractTransaction = await facade.connect(contractOwner).bidAmount(1, add1.address, add2.address, {
            value: ethers.utils.parseEther("10.0")
        });
        await bidAmountTx.wait();

        await expect(facade.connect(add2).endAuction(1)).to.be.revertedWith("Facade: Unauthorized Access!");

        const balanceOfArtist: BigNumber = await provider.getBalance(add1.address);
        const balanceOfPlatform: BigNumber = await provider.getBalance(platformAddress.address);
        const balanceOfNetwork: BigNumber = await provider.getBalance(networkAddress.address);

        console.log("Before: Artist Balance-> ", balanceOfArtist);
        console.log("Before: Platform Balance-> ", balanceOfPlatform);
        console.log("Before: Network Balance-> ", balanceOfNetwork);

        const endAuctionTx: ContractTransaction = await facade.connect(contractOwner).endAuction(1);
        await endAuctionTx.wait();

        const afterBalanceOfArtist: BigNumber = await provider.getBalance(add1.address);
        const afterBalanceOfPlatform: BigNumber = await provider.getBalance(platformAddress.address);
        const afterBalanceOfNetwork: BigNumber = await provider.getBalance(networkAddress.address);

        console.log("After: Artist Balance-> ", afterBalanceOfArtist);
        console.log("After: Platform Balance-> ", afterBalanceOfPlatform);
        console.log("After: Network Balance-> ", afterBalanceOfNetwork);


        // Artist Primary Sale Percentage 87. Then 87% of 10 = 8.7
        expect(Number(afterBalanceOfArtist)- Number(balanceOfArtist)).to.above(8.6e18);
        expect(Number(afterBalanceOfArtist)- Number(balanceOfArtist)).to.below(8.71e18);

        // Platform Primary Sale Percentage 10. Then 10% of 10 = 1
        expect(Number(afterBalanceOfPlatform) - Number(balanceOfPlatform)).to.be.above(0.9e18);
        expect(Number(afterBalanceOfPlatform) - Number(balanceOfPlatform)).to.be.below(1.1e18);

        // Network Primary Sale Percentage 3. Then 3% of 10 = 0.3
        expect(Number(afterBalanceOfNetwork)- Number(balanceOfNetwork)).to.be.above(0.2e18);
        expect(Number(afterBalanceOfNetwork) - Number(balanceOfNetwork)).to.be.below(0.31e18);


    });

    it("end Auction Function for Primary Sale with Collaborators", async () => {

        const { nft, marketplace, facade, contractOwner, platformAddress, networkAddress, add1, add2, add3, add4, add5, otherAccounts } = await loadFixture(deployOnceFixture);

        const mintTx: ContractTransaction = await facade.connect(contractOwner).mintToken("art", "art", add1.address);
        await mintTx.wait();

        const intializeAuctionTx: ContractTransaction = await facade.connect(contractOwner).intializeAuction(1, 3000000);
        await intializeAuctionTx.wait();

        //Set Collaborators
        const setCollaboratorsTx: ContractTransaction = await facade.connect(contractOwner).setCollaborators(1, [add4.address, add5.address], [25, 30]);
        await setCollaboratorsTx.wait();

        //Compulsory Step Token owner should approve facade contract address corresponding token id
        const approveTx: ContractTransaction = await nft.connect(add1).approve(facade.address, 1);
        await approveTx.wait();

        const bidAmountTx: ContractTransaction = await facade.connect(contractOwner).bidAmount(1, add1.address, add2.address, {
            value: ethers.utils.parseEther("10.0")
        });
        await bidAmountTx.wait();

        await expect(facade.connect(add2).endAuction(1)).to.be.revertedWith("Facade: Unauthorized Access!");

        const balanceOfArtist: BigNumber = await provider.getBalance(add1.address);
        const balanceOfPlatform: BigNumber = await provider.getBalance(platformAddress.address);
        const balanceOfNetwork: BigNumber = await provider.getBalance(networkAddress.address);

        //Collaborators Balance
        const balanceOfcollab1: BigNumber = await provider.getBalance(add4.address);
        const balanceOfcollab2: BigNumber = await provider.getBalance(add5.address);

        console.log("Before: Artist Balance-> ", balanceOfArtist);
        console.log("Before: Platform Balance-> ", balanceOfPlatform);
        console.log("Before: Network Balance-> ", balanceOfNetwork);
        console.log("Before: Collab1 Balance-> ", balanceOfcollab1);
        console.log("Before: Collab2 Balance-> ", balanceOfcollab2);

        const endAuctionTx: ContractTransaction = await facade.connect(contractOwner).endAuction(1);
        await endAuctionTx.wait();

        const afterBalanceOfArtist: BigNumber = await provider.getBalance(add1.address);
        const afterBalanceOfPlatform: BigNumber = await provider.getBalance(platformAddress.address);
        const afterBalanceOfNetwork: BigNumber = await provider.getBalance(networkAddress.address);

        const afterBalanceOfcollab1: BigNumber = await provider.getBalance(add4.address);
        const afterBalanceOfcollab2: BigNumber = await provider.getBalance(add5.address);

        console.log("After: Artist Balance-> ", afterBalanceOfArtist);
        console.log("After: Platform Balance-> ", afterBalanceOfPlatform);
        console.log("After: Network Balance-> ", afterBalanceOfNetwork);
        console.log("After: Collab1 Balance-> ", afterBalanceOfcollab1);
        console.log("After: Collab2 Balance-> ", afterBalanceOfcollab2);


        // General Artist Primary Sale Percentage 87. Then 87% of 10 = 8.7. This amount will be distributed among Artist, Collaborator1 and Collaborator2
        // here collaboretors percentage (25 + 30) = 55, so Artist percentage is (100-55) = 45 Then 45% of 8.7 = 3.915
        expect(Number(afterBalanceOfArtist)- Number(balanceOfArtist)).to.above(3.91e18);
        expect(Number(afterBalanceOfArtist)- Number(balanceOfArtist)).to.below(3.92e18);

        // Platform Primary Sale Percentage 10. Then 10% of 10 = 1
        expect(Number(afterBalanceOfPlatform) - Number(balanceOfPlatform)).to.be.above(0.9e18);
        expect(Number(afterBalanceOfPlatform) - Number(balanceOfPlatform)).to.be.below(1.1e18);

        // Network Primary Sale Percentage 3. Then 3% of 10 = 0.3
        expect(Number(afterBalanceOfNetwork)- Number(balanceOfNetwork)).to.be.above(0.2e18);
        expect(Number(afterBalanceOfNetwork) - Number(balanceOfNetwork)).to.be.below(0.31e18);

        // Collaborator 1 Primary Sale Percentage 25. Then 25% of 8.7 = 2.175
        expect(Number(afterBalanceOfcollab1) - Number(balanceOfcollab1)).to.be.above(2.17e18);
        expect(Number(afterBalanceOfcollab1) - Number(balanceOfcollab1)).to.be.below(2.18e18);

        // Collaborator 2 Primary Sale Percentage 30. Then 30% of 8.7 = 2.61
        expect(Number(afterBalanceOfcollab2)- Number(balanceOfcollab2)).to.be.above(2.6e18);
        expect(Number(afterBalanceOfcollab2) - Number(balanceOfcollab2)).to.be.below(2.7e18);


    });

});