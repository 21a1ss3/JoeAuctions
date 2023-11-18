// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAuction} from "./IAuction.sol";
import {IJoeMerchNft} from "./IJoeMerchNft.sol";

abstract contract JoeAuctionsGeneric is Ownable2Step, IAuction {
    constructor(address owner, address executor) 
        Ownable(owner) {

        _executor = executor;
        BestBidWallet = _bestBidDefault();
    }


    address                             private             _executor;
    uint40                              public              AuctionEndTime;

    address                             public              BestBidWallet;
    uint128                             public              LastBidSize;


    function _bidToken() internal virtual view returns (IERC20);
    function _bestBidDefault() internal virtual view returns (address); //TODO: Discuss value
    function _bidIncrement() internal virtual view returns (uint96);
    function _auctionTimeExtraWindow() internal virtual view returns (uint40);
    function _nftReward() internal virtual view returns (IJoeMerchNft);


    modifier onlyExecutor() {
        require(_executor == _msgSender(), "Unauthorized (E)");
        _;
    }

    function Multicall(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] memory calldatas
       )
    public virtual payable onlyOwner {
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success,) = targets[i].call{value: values[i]}(calldatas[i]);

            require(success, "Unable to perfroma a call");
        }
    }

    function SetExecutor(address executor) public onlyOwner {
        _executor = executor;
    }

    function Withdraw() public onlyExecutor {
        uint256 bidAmount = 0;

        if (IsAlive() && (BestBidWallet != _bestBidDefault())) 
            bidAmount = LastBidSize;

        _bidToken().transfer(owner(), _bidToken().balanceOf(address(this)) - bidAmount);        
    }

    function LaunchAuction(uint40 endTime, uint128 minBid) public onlyExecutor {
        require(!IsAlive(), "Auction in place, cannot start new");

        _issueUserReward();

        AuctionEndTime = endTime;

        BestBidWallet = _bestBidDefault();
        LastBidSize = minBid;

        //TODO: Emit event
    }

    function IssueUserReward() public { //onlyExecutor?
        _issueUserReward();
    }

    function _issueUserReward() private {
        address bestBidUser = BestBidWallet;

        if (bestBidUser != _bestBidDefault()) {
            BestBidWallet = _bestBidDefault();

            _nftReward().Mint(bestBidUser);
            //TODO: issue a log for reward
        }
    }

    function _isAlive(uint40 endTime) private view returns (bool) {
        return block.timestamp <= endTime;
        
    }

    function IsAlive() public view returns (bool) {
        return _isAlive(AuctionEndTime);
    }

    function PlaceBid(uint256 bidSize) public {
        //require(_msgSender().code.length == 0, "Only EOA can place a bids");
        require(bidSize < type(uint128).max, "bidSize too big");

        {
            uint40 auctionEndTime = AuctionEndTime;

            require(_isAlive(auctionEndTime), "No active auctions");
            uint40 timeToEnd = uint40(auctionEndTime - block.timestamp);
            if (timeToEnd < _auctionTimeExtraWindow())
                AuctionEndTime = auctionEndTime + timeToEnd;
        }

        uint128 lastBid = LastBidSize;

        require((lastBid + _bidIncrement()) >= bidSize, "New bid shall be greater or equal on BidOveralp to current best bid");

        address refundUser = BestBidWallet;   
        uint128 bidTotal = uint128(bidSize);

        if (refundUser == _msgSender())
        {
            bidTotal += lastBid;
            refundUser = _bestBidDefault();
            lastBid = 0;
        }
        
        LastBidSize = bidTotal;
        BestBidWallet = _msgSender();

        _bidToken().transferFrom(_msgSender(), address(this), bidSize);
        if (refundUser != _bestBidDefault())
            _bidToken().transfer(refundUser, lastBid);

        //TODO: Issue event
    }
}
