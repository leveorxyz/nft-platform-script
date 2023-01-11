// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IFacade {

    // Struct
    struct Token {
        uint256 _tokenId;
        address _creator;
        address _artist;
        address _currentOwner;
        string _uri;
        string _title;
    }

    // Events
    event ownershipTransfer(address _from, address _to);

    event MintToken(
        string uri,
        string title,
        uint256 tokenId
    );

    event Transfer(
        uint256 _tokenId,
        address _owner,
        address _recipient
    );

    event AdminCreated(
        address newAdminAddress
    );


    /**
     * @notice This method is used to Mint a new Token
     *
     * @return uint256 Token Id of the Minted Token
     */
    function mintToken(
        string calldata uri,
        string calldata title,
        address _tokenOwner
    ) external returns (uint256);


    /**
     * @notice This method is used to get details of the Token with ID _tokenID
     *
     * @param _tokenId TokenID of the Token to get details of
     *
     * @return Token Structure of the Token
     */
    function getToken(uint256 _tokenId)
        external
        view
        returns (Token memory);


    /**
     * @notice This method is used intialize any auction
     *
     * @param _tokenId TokenID of the Token to get details of
     *
     * @return bool value
     */
    function intializeAuction(uint256 _tokenId, uint _biddingTime) external returns(bool);


    /**
     * @notice This method is used bid of any auction
     *
     * @param _tokenId TokenID of the Token to get details of
     *
     * @return bool value
     */
    function bidAmount(
        uint256 _tokenId,
        address _owner,
        address _bidderAddress
    ) external payable returns (bool);


    /**
     * @notice This method is used end any auction only auction creator can call
     *
     * @param _tokenId TokenID of the Token to get details of
     *
     * @return bool value
     */
    function endAuction(
        uint256 _tokenId
    ) external returns (bool);


    /**
     * @notice This method is used to withdraw any overbid amount
     *
     * @param _tokenId TokenID of the Token to get details of
     *
     * @return bool value
     */
    function withDrawOverbidAmount(uint256 _tokenId, address _overBidderAddress) external returns (bool);


    function setAdminAddress(address adminAddress)
        external
        returns (bool);

    function setCollaborators(uint256 _tokenId, address[] memory collaborators, uint256[] calldata percentages) external returns (bool);


}