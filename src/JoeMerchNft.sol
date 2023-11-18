// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IAuction} from "./IAuction.sol";
import {IJoeMerchNft} from "./IJoeMerchNft.sol";

contract JoeMerchNft is ERC721, Ownable2Step, IJoeMerchNft {
    constructor(address owner)
        ERC721("Joe Merch", "") Ownable(owner)
    {
            Auction = address(0);
            LastTokenId = 1;
    }

    address                 public                  Auction;
    uint128                 public                  LastTokenId;
    bool                    public                  TransferDisabled = true;

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
        _mint(user, LastTokenId);
        LastTokenId++;
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        if (TransferDisabled && (to != address(0)))
            _validateAuctionSender();

        return super._update(to, tokenId, auth);
    }
}