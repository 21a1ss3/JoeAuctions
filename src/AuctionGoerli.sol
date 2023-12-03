// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./JoeAuctionsGeneric.sol";


contract JoeAuctionsGoerli is JoeAuctionsGeneric {
    constructor(address owner, address executor)
    JoeAuctionsGeneric(owner, executor) {
        BidIncrement = 1000 ether; //ether
        AuctionTimeExtraWindow = 15 minutes;
    }


    function _bidToken() internal override pure returns (IERC20) { return IERC20(0x1544E17C3a17B2EeD9106c060aeb383A4d25E1C9); }
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