// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct Listing {
    uint256 price;
    address seller;
}

contract NFTMarketplace is ReentrancyGuard, Ownable, ERC721Holder {
    constructor() Ownable(msg.sender) {}
    
    mapping(address => mapping(uint256 => Listing)) public listings;

    event NFTListed(address indexed nftAddress, uint256 indexed tokenId, uint256 price, address seller);

    event NFTBought(address indexed nftAddress, uint256 indexed tokenId, uint256 price, address buyer, address seller);

    event NFTListingCanceled(address indexed nftAddress, uint256 indexed tokenId, address seller);

    function listNFT(address _nftAddress, uint256 _tokenId, uint256 _price) external nonReentrant {
        require(_price > 0, "Price must be greater than zero");
        require(IERC721(_nftAddress).ownerOf(_tokenId) == msg.sender, "You are not the owner of this NFT");
        require(IERC721(_nftAddress).getApproved(_tokenId) == address(this), "Marketplace is not approved");

        listings[_nftAddress][_tokenId] = Listing(_price, msg.sender);

        IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);

        emit NFTListed(_nftAddress, _tokenId, _price, msg.sender);
    }

    function buyNFT(address _nftAddress, uint256 _tokenId) external payable nonReentrant {
        Listing memory listing = listings[_nftAddress][_tokenId];
        require(listing.price > 0, "NFT is not listed for sale");
        require(msg.value == listing.price, "Incorrect payment amount");
        
        (bool success, ) = payable(listing.seller).call{value: msg.value}("");
        require(success, "Payment transfer failed");
        
        IERC721(_nftAddress).safeTransferFrom(address(this), msg.sender, _tokenId);
        
        delete listings[_nftAddress][_tokenId];
        
        emit NFTBought(_nftAddress, _tokenId, listing.price, msg.sender, listing.seller);
    }

    function cancelListing(address _nftAddress, uint256 _tokenId) external nonReentrant {
        Listing memory listing = listings[_nftAddress][_tokenId];
        require(listing.seller == msg.sender, "You are not the seller");

        IERC721(_nftAddress).safeTransferFrom(address(this), msg.sender, _tokenId);

        delete listings[_nftAddress][_tokenId];

        emit NFTListingCanceled(_nftAddress, _tokenId, msg.sender);
    }

    function withdrawFunds() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Withdraw failed");
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
