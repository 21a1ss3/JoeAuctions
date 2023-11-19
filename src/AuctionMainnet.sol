// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./AuctionGenericV1.sol";


contract JoeAuctionsMainnet is JoeAuctionsGeneric {
    constructor(address owner, address executor)
    JoeAuctionsGeneric(owner, executor) {
        BidIncrement = 1000 ether; //ether
        AuctionTimeExtraWindow = 15 minutes;
    }


    function _bidToken() internal override pure returns (IERC20) { return IERC20(0x76e222b07C53D28b89b0bAc18602810Fc22B49A8); }
    function _bestBidDefault() internal override pure returns (address) { return address(type(uint160).max); }
    function _bidIncrement() internal override view returns (uint96) { return BidIncrement; }
    function _auctionTimeExtraWindow() internal override view returns (uint40) { return AuctionTimeExtraWindow; }    
    function _nftReward() internal override view returns (IJoeMerchNft) { return IJoeMerchNft(MerchNft); }

    uint96                              public              BidIncrement;
    uint40                              public              AuctionTimeExtraWindow;
    address                             public              MerchNft;

    function SetBidIncrement(uint96 newValue) public onlyOwner {
        BidIncrement = newValue;
    }
    
    function SetAuctionTimeExtraWindow(uint40 newValue) public onlyOwner {
        AuctionTimeExtraWindow = newValue;
    }

    function SetMerchNft(address newValue) public onlyOwner {
        MerchNft = newValue;
    }
}