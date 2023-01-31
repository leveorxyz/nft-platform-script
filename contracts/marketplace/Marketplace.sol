// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/IMarketplace.sol";


contract Marketplace is IMarketplace, Ownable, ReentrancyGuard {

    address _facadeContract;

    address _contractOwner;

    modifier onlyContractOwner {
        require(
            msg.sender == _contractOwner,
            "Marketplace: Only Contract owner can access !"
        );
        _;
    }

    modifier onlyFacadeCaller {
        require(
            msg.sender == _facadeContract,
            "Marketplace: Unauthorized Access!"
        );
        _;
    }

    function configureFacadeCaller(address _facadeContractAddress) external onlyContractOwner {
        require(
            _facadeContractAddress != address(0),
            "Marketplace: Invalid Facade Contract Address!"
        );
        require(
            _facadeContract == address(0),
            "Marketplace: Facade Contract Caller Already Configured!"
        );

        _facadeContract = _facadeContractAddress;
    }


    // Market Primary and Secondary Sale address and Percentage
    address platformAddress;
    address networkAddress;
    uint256 platformPrimaryPercentage;
    uint256 networkPrimaryPercentage;
    uint256 platformSecondaryPercentage;
    uint256 networkSecondaryPercentage;

    // Artist or Nft Creator Primary and Secondary Percentage
    uint256 nftCreatorPrimaryPercentage;
    uint256 nftCreatorSecondaryPercentage;


    // tokenID => auctionInfo struct
    mapping(uint256 => auctionInfo) private auctionInfos;

    // tokenID => highest Bid Info
    mapping(uint256 => highestBidInfo) private highestBidInfos;

    // tokenID => Artist
    mapping(uint256 => address) private nftArtistAddresses;


    // tokenID => Allowed withdrawals of previous bids
    mapping(uint256 => mapping(address => uint)) pendingReturns;

    // tokenID => { collaboratorsAddresses[] , percentages[] }
    mapping(uint256 => Collaborators) private tokenCollaborators;


    // tokenID => secondary sale or not (default false means primary sale)
    mapping(uint256 => bool) isSecondary;

    fallback() external {}

    receive() external payable {}


    constructor(
        address _platformAddress,
        address _networkAddress,
        uint256 _platformPrimaryPercentage,
        uint256 _networkPrimaryPercentage,
        uint256 _platformSecondaryPercentage,
        uint256 _networkSecondaryPercentage,
        uint256 artistPrimaryPercentage,
        uint256 artistSecondaryPercentage
    ) {
        platformAddress = _platformAddress;
        networkAddress = _networkAddress;
        platformPrimaryPercentage = _platformPrimaryPercentage;
        platformSecondaryPercentage = _platformSecondaryPercentage;
        networkPrimaryPercentage = _networkPrimaryPercentage;
        networkSecondaryPercentage = _networkSecondaryPercentage;
        nftCreatorPrimaryPercentage = artistPrimaryPercentage;
        nftCreatorSecondaryPercentage = artistSecondaryPercentage;

        _contractOwner = msg.sender;
    }



    function auctionStart(uint256 _tokenId, uint _biddingTime, address nftArtistAddress, address nftOwnerAddress) external onlyFacadeCaller override {

        require(auctionInfos[_tokenId].started == false, "Marketplace: There is already an ongoing auction for this tokenId!");

        uint biddingEndTime = block.timestamp + _biddingTime;
        nftArtistAddresses[_tokenId] = nftArtistAddress;
        auctionInfos[_tokenId] = auctionInfo (nftOwnerAddress, biddingEndTime, true);

        emit AuctionStarted(_tokenId, nftOwnerAddress, biddingEndTime);

    }

    
    function bid(uint256 _tokenId, address bidder, uint256 auctionAmount, address _tokenOwner) external payable onlyFacadeCaller override returns(bool) {

        // Revert the call if the bidding
        // period is over.
        require(
            block.timestamp <= auctionInfos[_tokenId].auctionEndTime,
            "Auction already ended."
        );

        // If the bid is not higher, send the
        // money back (the failing require
        // will revert all changes in this
        // function execution including
        // it having received the money).
        require(
            auctionAmount > highestBidInfos[_tokenId].highestBid,
            "There already is a higher bid."
        );

        if (highestBidInfos[_tokenId].highestBid != 0) {
            // Sending back the money by simply using
            // highestBidder.send(highestBid) is a security risk
            // because it could execute an untrusted contract.
            // It is always safer to let the recipients
            // withdraw their money themselves.
            pendingReturns[_tokenId][highestBidInfos[_tokenId].highestBidder] += highestBidInfos[_tokenId].highestBid;
        }
        highestBidInfos[_tokenId].highestBidder = bidder;
        highestBidInfos[_tokenId].highestBid = auctionAmount;

        emit HighestBidIncreased(_tokenId, bidder, auctionAmount, _tokenOwner);

        return true;
    }

    /// Withdraw a bid that was overbid.
    function withdraw(uint256 _tokenId, address withDrawerAddress) external onlyFacadeCaller nonReentrant override {

        uint amount = pendingReturns[_tokenId][withDrawerAddress];

        require(amount > 0, "Marketplace: Withdraw amount should not be zero");

        pendingReturns[_tokenId][withDrawerAddress] = 0;

        //payable(withDrawerAddress).transfer(amount);

        (bool success, ) = address(withDrawerAddress).call{ value: amount }("");
        require(success, "Withdraw amount failed to send");

        emit withdrawSucceed(_tokenId, withDrawerAddress, amount);
    }

    /// End the auction and send the highest bid
    /// to the beneficiary.
    function auctionEnd(uint256 _tokenId) external nonReentrant override onlyFacadeCaller returns(address) {

        // 2. Effects
        auctionInfos[_tokenId].started = false;

        address bidder = highestBidInfos[_tokenId].highestBidder;
        uint bidAmount = highestBidInfos[_tokenId].highestBid;

        // 3. Interaction
        divideMoney(_tokenId);
        
        delete auctionInfos[_tokenId];

        delete highestBidInfos[_tokenId];

        emit AuctionEnded(_tokenId, bidder, bidAmount);

        return bidder;

    }

    function setCollaborators(
        uint256 _tokenId,
        Collaborators calldata _collaborators
    ) external override onlyFacadeCaller {
        tokenCollaborators[_tokenId] = _collaborators;
    }


    function divideMoney(uint256 _tokenId) internal {

        uint256 totalAmount = highestBidInfos[_tokenId].highestBid;

        // Primary Sale
        if(!isSecondary[_tokenId]){

            isSecondary[_tokenId] = true;
            
           // Share money to Platform Address
            
            (bool successNFTCart, ) = address(platformAddress).call{ value: (totalAmount*(platformPrimaryPercentage))/100}("");
            require(successNFTCart, "Marketplace: Platform Percentage failed to send");

            // Share money to Network Address

            (bool successNetwork, ) = address(networkAddress).call{ value: (totalAmount*(networkPrimaryPercentage))/100}("");
            require(successNetwork, "Marketplace: Network Percentage failed to send");

            // Share money to Artist or Nft Creator

            if(tokenCollaborators[_tokenId]._collaborators.length > 0 ) {
                uint256 artistAmount = (totalAmount*(nftCreatorPrimaryPercentage))/100;

                Collaborators memory tokenColab = tokenCollaborators[_tokenId];

                uint256 collaboratorsTotalPercentage = 0;

                for (
                  uint256 index = 0;
                  index < tokenColab._collaborators.length;
                  index++
                ) {
                    collaboratorsTotalPercentage += tokenColab._percentages[index];
                    
                    (bool successCollab, ) = address(tokenColab._collaborators[index]).call{ value: (artistAmount * (tokenColab._percentages[index]))/100}("");
                    require(successCollab, "Marketplace: Collaborators Percentage failed to send");

                }

                uint256 artistPercent = 100 - collaboratorsTotalPercentage;

                (bool successArtist, ) = address(nftArtistAddresses[_tokenId]).call{ value: (artistAmount*(artistPercent))/100}("");
                require(successArtist, "Marketplace: Artist Percentage failed to send");

            } else{
                (bool successArtist, ) = address(nftArtistAddresses[_tokenId]).call{ value: (totalAmount*(nftCreatorPrimaryPercentage))/100}("");
                require(successArtist, "Marketplace: Artist Percentage failed to send");
            }

        } else{
             
        uint256 totalPercentage = 100;
        uint256 otherShare = nftCreatorSecondaryPercentage+platformSecondaryPercentage+networkSecondaryPercentage;
        uint256 tokenOwnerShare = totalPercentage-otherShare;

        // Share money to Platform Address
        (bool successNFTCart, ) = address(platformAddress).call{ value: (totalAmount*(platformSecondaryPercentage))/100}("");
        require(successNFTCart, "Marketplace: Platform Percentage failed to send");

        // Share money to Network Address
        (bool successNetwork, ) = address(networkAddress).call{ value: (totalAmount*(networkSecondaryPercentage))/100}("");
        require(successNetwork, "Marketplace: Network Percentage failed to send");

        // Share money to Artist or Nft Creator

        (bool successArtist, ) = address(nftArtistAddresses[_tokenId]).call{ value: (totalAmount*(nftCreatorSecondaryPercentage))/100}("");
        require(successArtist, "Marketplace: Artist Percentage failed to send");

        // Share money to Nft owner or who created the auction

        (bool successOwner, ) = address(auctionInfos[_tokenId]._creator).call{ value: (totalAmount*(tokenOwnerShare))/100}("");
        require(successOwner, "Marketplace: Owner Percentage failed to send");
      }
    }
}