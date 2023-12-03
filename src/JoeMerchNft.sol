// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IAuction} from "./IAuction.sol";
import {IJoeMerchNft} from "./IJoeMerchNft.sol";

contract JoeMerchNft is ERC721, Ownable2Step, IJoeMerchNft {
    constructor(address owner)
        ERC721("Joe Merch", "$JOE") Ownable(owner)
    {
            Auction = address(0);
            LastTokenId = 0;

            _name = "Joe Merch";
            _symbol = "$JOE";
    }

    address                         public                  Auction;
    uint128                         public                  LastTokenId;
    bool                            public                  TransferDisabled = true;
    string                          private                 _name;
    string                          private                 _symbol;
    string                          private                 _baseUri;
    mapping(uint256 => string)      public                  TokenUriOverride;

    function SetAuction(address auction) public onlyOwner {
        Auction = auction;
    }

    function SetTransferMode(bool transferDisabled) public onlyOwner {
        TransferDisabled = transferDisabled;
    }

    modifier onlyAuction() {
        require(Auction == _msgSender(), "Unauthorized (A)");
        _;
    }

    function _validateAuctionSender() private onlyAuction{

    }


    function Mint(address user) public onlyAuction {
        _mint(user, ++LastTokenId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        if (TransferDisabled && (to != address(0)))
            _validateAuctionSender();

        return super._update(to, tokenId, auth);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        string memory urlOverride = TokenUriOverride[tokenId];
        if (bytes(urlOverride).length > 0)
            return urlOverride;

        return super.tokenURI(tokenId);
    }

    
    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
    }

    
    function SetName(string calldata newValue) public onlyOwner {
        _name = newValue;
    }

    function SetSymbol(string calldata newValue) public onlyOwner {
        _symbol = newValue;
    }

    function SetBaseUri(string calldata uri) public onlyOwner {
        _baseUri = uri;
    }

    function OverriedTokenUri(uint256 tokenId, string calldata uri) public onlyOwner {
        TokenUriOverride[tokenId] = uri;
    }
}