// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract NFT is ERC721, ERC721URIStorage, Pausable, Ownable {
    
    address _facadeContract;

    address _contractOwner;

    modifier onlyContractOwner {
        require(
            msg.sender == _contractOwner,
            "NFT: Only Contract owner can access !"
        );
        _;
    }

    modifier onlyFacadeCaller {
        require(
            msg.sender == _facadeContract,
            "NFT: Unauthorized Access!"
        );
        _;
    }

    function configureFacadeCaller(address _facadeContractAddress) external onlyContractOwner {
        
        require(
            _facadeContractAddress != address(0),
            "NFT Cart: Invalid Facade Contract Address!"
        );
        require(
            _facadeContract == address(0),
            "NFT Cart: Facade Contract Caller Already Configured!"
        );

        _facadeContract = _facadeContractAddress;
    }

    // tokenID => Creator
    mapping(uint256 => address) nftCreators;
    // tokenId => Owner
    mapping(uint256 => address) nftOwners;

    
    constructor() ERC721("Sample NFT", "NFT") ERC721URIStorage() Pausable() {
         _contractOwner = msg.sender;
    }


    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(uint256 _tokenId, address to, string memory uri) public onlyFacadeCaller {
        nftCreators[_tokenId] = to;
        nftOwners[_tokenId] = to;
        _safeMint(to, _tokenId);
        _setTokenURI(_tokenId, uri);
    }

    function transfer(address _recipient, uint256 _tokenId)
        public
        onlyFacadeCaller
        returns (bool)
    {
        require(_tokenId > 0, "NFT: Token Id should be non-zero");
        transferFrom(msg.sender, _recipient, _tokenId); // ERC721 transferFrom function called
        nftOwners[_tokenId] = _recipient;
        return true;
    }

    function TransferFrom(
        address _sender,
        address _recipient,
        uint256 _tokenId
    ) public onlyFacadeCaller returns (bool) {
        require(_tokenId > 0, "NFT: Token Id should be non-zero");

        safeTransferFrom(_sender, _recipient, _tokenId);

        nftOwners[_tokenId] = _recipient;
        return true;
    }

    function _burn(uint256 tokenId)
        internal
        onlyFacadeCaller
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        onlyFacadeCaller
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}