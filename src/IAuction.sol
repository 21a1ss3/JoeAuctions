// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract IAuction { // is IERC20
    //Total supply is 1b *10^18. log_2 (1b *10^18) < 90

    struct AuctionEntry {
        uint96 CurrentUserBid; //TODO: 3rd question
        //uint96 Refund; //TODO: 3rd question
        uint40  BidTime;
    }


}