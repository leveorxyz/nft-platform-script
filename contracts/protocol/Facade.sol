// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../tokenization/NFT.sol";
import "../marketplace/Marketplace.sol";
import "../interfaces/IMarketplace.sol";
import "../interfaces/IFacade.sol";

import "@openzeppelin/contracts/utils/Counters.sol";


contract Facade is IFacade {

    using Counters for Counters.Counter;
    Counters.Counter private tokenIdCounter;


    address nftAddress;

    address marketAddress;

    address contractOwner;

    address[] adminAddresses;


    // tokenId => Owner
    mapping(uint256 => address) public nftOwners;

    // tokenId => Creator
    mapping(uint256 => address) public nftCreators;

    // tokenId => Artist
    mapping(uint256 => address) public nftArtists;

    // tokenId => Token
    mapping(uint256 => Token) tokenIdToken;

    // address => True
    mapping(address => bool) adminAddressExist;

    // token uriOrtitle => tokenId
    mapping(string => uint256) private tokenUriOrTitleToTokenId;


    modifier isTokenExist(uint256 _tokenId) {
        require(
            tokenIdToken[_tokenId]._creator != address(0),
            "Facade: The Token Doesn't Exist!"
        );
        _;
    }

    modifier onlyContractOwnerOrAdmin() {
        require(msg.sender == contractOwner || adminAddressExist[msg.sender] == true, "Facade: Unauthorized Access!");
        _;
    }

    constructor(
        address _nftAddress,
        address _marketAddress
    ) {
        require(_nftAddress != address(0), "Facade: Provide ERC721 Contract Address!");
        require(_marketAddress != address(0), "Facade: Provide Market Address!");

        nftAddress = _nftAddress;
        marketAddress = _marketAddress;
        contractOwner = msg.sender;
    }

    function transferOwnership(address _newOwner) external onlyContractOwnerOrAdmin {
        require(_newOwner != address(0), "Facade: Provide NewOwner Address!");
        emit ownershipTransfer(contractOwner, _newOwner);
        contractOwner = _newOwner;
    }

    function mintToken(
        string calldata uri,
        string calldata title,
        address _tokenOwner
    ) external onlyContractOwnerOrAdmin override returns (uint256) {

        // Check if Token with same uri exists
        require(
            tokenUriOrTitleToTokenId[uri] == 0 && tokenUriOrTitleToTokenId[title] == 0,
            "Facade: Token With same uri or title Exist!"
        );
        
        /*if(adminAddressExist[msg.sender] == false){
            if(msg.sender != _tokenOwner){
                revert("Facade: Only Admin or One can mint tokens for oneself !");
            }
        }*/

       tokenIdCounter.increment();
       uint256 tokenId = tokenIdCounter.current();

        // Store the uri
        tokenUriOrTitleToTokenId[uri] = tokenId;

        // Store the title
        tokenUriOrTitleToTokenId[title] = tokenId;

        
        NFT(nftAddress).safeMint(tokenId, _tokenOwner, uri);

        nftOwners[tokenId] = _tokenOwner;
        nftCreators[tokenId] = msg.sender;
        nftArtists[tokenId] = _tokenOwner;

        Token memory newToken = Token(
            tokenId,
            msg.sender,
            _tokenOwner,
            _tokenOwner,
            uri,
            title
        );

        tokenIdToken[tokenId] = newToken;

        emit MintToken(
            uri,
            title,
            tokenId
        );

        return tokenId;
    }

    function getToken(uint256 _tokenId)
        external
        override
        view
        isTokenExist(_tokenId)
        returns (Token memory)
    {
        return tokenIdToken[_tokenId];
    }

    function getTotalNumberOfNft() external view returns (uint256) {
        uint256 tokenId = tokenIdCounter.current();
        return tokenId;
    }

    function setCollaborators(uint256 _tokenId, address[] memory collaborators, uint256[] calldata percentages) external onlyContractOwnerOrAdmin override isTokenExist(_tokenId) returns (bool){

        /*require(
             nftOwners[_tokenId] == msg.sender || adminAddressExist[msg.sender] == true,
            "Facade: Only Token Owner or Admin can set collaborators!"
        );*/
        IMarketplace.Collaborators memory newTokenColab = IMarketplace.Collaborators(
            collaborators,
            percentages
        );

        IMarketplace(payable(marketAddress)).setCollaborators(_tokenId, newTokenColab);

        return true;
    }

    function intializeAuction(uint256 _tokenId, uint _biddingTime) external onlyContractOwnerOrAdmin override isTokenExist(_tokenId) {

        /*require(
             nftOwners[_tokenId] == msg.sender || adminAddressExist[msg.sender] == true,
            "Facade: Only Token Owner or Admin can start Auction!"
        );*/

        address nftArtistAddress = nftArtists[_tokenId];
        address nftOwnerAddress = nftOwners[_tokenId];
        IMarketplace(payable(marketAddress)).auctionStart(_tokenId, _biddingTime, nftArtistAddress, nftOwnerAddress);
        
        emit AuctionStart(_tokenId, _biddingTime);
    }

    function bidAmount(
        uint256 _tokenId,
        address _owner,
        address _bidderAddress
    ) external onlyContractOwnerOrAdmin payable override isTokenExist(_tokenId) returns (bool) {
        require(msg.value != 0, "Facade: You can't bid with 0 amount!");
        require(
            tokenIdToken[_tokenId]._currentOwner != _bidderAddress,
            "Facade: The token current owner can not bid!"
        );
        require(
                nftOwners[_tokenId] == _owner,
                "Facade: Invalid owner address provided!"
        );
        
        // amount, tokenOwner

        bool isSuccess = IMarketplace(payable(marketAddress)).bid(
            _tokenId,
            _bidderAddress,
            msg.value,
            _owner
        );

        if(isSuccess){
           payable(marketAddress).transfer(msg.value);
           return true;
        } else {
            return false;
        }
    }

    function endAuction(
        uint256 _tokenId
    ) external onlyContractOwnerOrAdmin override isTokenExist(_tokenId) returns (bool) {
         /*require(
            nftOwners[_tokenId] == msg.sender || adminAddressExist[msg.sender] == true,
            "Facade: Only Owner or Admin can end Auction!"
        );*/
        address highestBidder = IMarketplace(payable(marketAddress)).auctionEnd(
            _tokenId
        );

        //_transfer(_tokenId, nftOwners[_tokenId], highestBidder);

        nftOwners[_tokenId] = highestBidder;
        tokenIdToken[_tokenId]._currentOwner = highestBidder;
        return true;
    }

   
    function setAdminAddress(address adminAddress)
        external
        override
        onlyContractOwnerOrAdmin
        returns (bool)
    {
        require(
            adminAddress != address(0),
            "Facade: Invalid Admin Address!"
        );

        adminAddresses.push(adminAddress);
        adminAddressExist[adminAddress] = true;

        emit AdminCreated(adminAddress);

        return true;
    }

    function withDrawOverbidAmount(uint256 _tokenId, address _overBidderAddress) external onlyContractOwnerOrAdmin override isTokenExist(_tokenId) returns (bool){

        require(
            _overBidderAddress != address(0),
            "Facade: Invalid over Bidder Address!"
        );
        bool isSuccess = IMarketplace(payable(marketAddress)).withdraw(_tokenId, _overBidderAddress);

        if(isSuccess){
           return true;
        }else{
            return false;
        }
        
    }

    function _transfer(
        uint256 _tokenId,
        address _owner,
        address _recipient
    ) internal {
        
            NFT(nftAddress).TransferFrom(
                _owner,
                _recipient,
                _tokenId
            );

            tokenIdToken[_tokenId]._currentOwner = _recipient;

        emit Transfer(_tokenId, _owner, _recipient);
    }
}