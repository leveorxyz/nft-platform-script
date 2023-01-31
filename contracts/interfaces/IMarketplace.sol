// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IMarketplace {

    // Struct
    struct highestBidInfo {
        address highestBidder;
        uint highestBid;
    }

    struct auctionInfo {
        address _creator;
        uint auctionEndTime;
        bool started;
    }

    struct Collaborators {
        address[] _collaborators;
        uint256[] _percentages;
    }

    // Events that will be emitted on changes.
    event HighestBidIncreased(uint256 tokenId, address bidder, uint amount, address tokenOwner);
    event AuctionEnded(uint256 tokenId, address winner, uint amount);
    event AuctionStarted(uint256 tokenId, address creator, uint auctionEndTime);
    event withdrawSucceed (
       uint256 _tokenId,
       address _withDrawer,
       uint256 _withDrawAmount
    );

    /**
     * @notice This method is used to start any auction
     *
     * @param _tokenId TokenID of the Token to get details of
     *
     */
    function auctionStart(uint256 _tokenId, uint _biddingTime, address nftArtistAddress, address nftOwnerAddress) external;

    /**
     * @notice This method is used bid of any auction
     *
     * @param _tokenId TokenID of the Token to get details of
     *
     * @return bool value
     */
    function bid(uint256 _tokenId, address bidder, uint256 auctionAmount, address _tokenOwner) external payable returns(bool);


    /**
     * @notice This method is used to withdraw any overbid amount
     *
     * @param _tokenId TokenID of the Token to get details of
     *
     */
    function withdraw(uint256 _tokenId, address withDrawerAddress) external;


    /**
     * @notice This method is used end any auction only auction creator can call
     *
     * @param _tokenId TokenID of the Token to get details of
     *
     * @return bool value
     */
    function auctionEnd(uint256 _tokenId) external returns(address);

    function setCollaborators(
        uint256 _tokenId,
        Collaborators calldata _collaborators
    ) external;



}