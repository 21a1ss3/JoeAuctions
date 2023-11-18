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

        AuctionEntry memory emptyBid;

        emptyBid.BidTime = 1; //Gas saving
        emptyBid.CurrentUserBid = 0; 
        //emptyBid.Refund = 0;

        Bids[_bestBidDefault()] = emptyBid;
        BestBidWallet = _bestBidDefault();
    }


    address                             private             _executor;
    uint40                              public              AuctionEndTime;
    uint40                              public              AuctionStartTime;

    address                             public              BestBidWallet;
    mapping(address => AuctionEntry)    public              Bids;
    uint96                              public              WithdrawBalance;




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
        uint256 withdrawAmount = WithdrawBalance;

        WithdrawBalance = 0;

        _bidToken().transfer(owner(), withdrawAmount);
    }

    function LaunchAuction(uint40 endTime, uint96 minBid) public onlyExecutor {
        require(!IsAlive(), "Auction in place, cannot start new");

        _issueUserReward();

        AuctionEndTime = endTime;
        AuctionStartTime = uint40(block.timestamp);

        BestBidWallet = _bestBidDefault();
        Bids[_bestBidDefault()].CurrentUserBid = minBid;

        //TODO: Emit event
    }

    function IssueUserReward() public { //onlyExecutor?
        _issueUserReward();
    }

    function _issueUserReward() private {
        if (IsAlive())
            return;

        address bestBidUser = BestBidWallet;

        if (bestBidUser != _bestBidDefault() && (Bids[bestBidUser].CurrentUserBid != 0)) {
            WithdrawBalance += Bids[bestBidUser].CurrentUserBid;
            Bids[bestBidUser].CurrentUserBid = 0;

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

    function IncreaseBid(uint256 bidSize) public {
        //require(_msgSender().code.length == 0, "Only EOA can place a bids");
        require(bidSize < type(uint96).max, "bidSize too big");

        uint40 auctionEndTime = AuctionEndTime;
        require(_isAlive(auctionEndTime), "No active auctions");
        
        AuctionEntry memory userEntry = Bids[_msgSender()];

        userEntry.BidTime = AuctionStartTime;
        userEntry.CurrentUserBid += uint96(bidSize);
        require(
            (userEntry.CurrentUserBid + _bidIncrement()) >= Bids[BestBidWallet].CurrentUserBid,
            "New bid shall be greater or equal on BidIncrement to current best bid"
        );
        Bids[_msgSender()] = userEntry;
        BestBidWallet = _msgSender();

        uint40 timeToEnd = uint40(auctionEndTime - block.timestamp);

        if (timeToEnd < _auctionTimeExtraWindow())
            AuctionEndTime = auctionEndTime + timeToEnd;

        _bidToken().transferFrom(_msgSender(), address(this), bidSize);

        //TODO: Issue event
    }

    function RedeemRefund() public {
        AuctionEntry memory userEntry = Bids[_msgSender()];
        uint40 auctionStartTime = AuctionStartTime;

        //if user in the competition
        if (
            IsAlive() 
            &&
            (userEntry.BidTime == auctionStartTime)
        )
            return;

        // if user won
        if (BestBidWallet == _msgSender())
            return;

        uint256 repayAmount = userEntry.CurrentUserBid;     //Re-entarnce protection
        userEntry.CurrentUserBid = 0;
        Bids[_msgSender()] = userEntry;

        _bidToken().transfer(_msgSender(), repayAmount);

        //TODO: Do we need an event?
    }

}
