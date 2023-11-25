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

        Executor = executor;

        AuctionEntry memory emptyBid;

        emptyBid.BidTime = 1; //Gas saving
        emptyBid.CurrentUserBid = 0; 
        //emptyBid.Refund = 0;

        Bids[_bestBidDefault()] = emptyBid;
        BestBidWallet = _bestBidDefault();
    }


    address                             public              Executor;
    uint40                              public              AuctionEndTime;
    uint40                              public              AuctionStartTime;

    address                             public              BestBidWallet;
    mapping(address => AuctionEntry)    public              Bids;
    uint96                              public              WithdrawBalance;




    function _bidToken() internal virtual view returns (IERC20);
    function _bestBidDefault() internal virtual view returns (address);
    function _bidIncrement() internal virtual view returns (uint96);
    function _auctionTimeExtraWindow() internal virtual view returns (uint40);
    function _nftReward() internal virtual view returns (IJoeMerchNft);


    modifier onlyExecutor() {
        require(Executor == _msgSender(), "Unauthorized (E)");
        _;
    }

    //May be replace this function with some other "emergency" or "anti-stuck" measures?
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
        Executor = executor;
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

        emit AuctionLaunched(block.timestamp, endTime, minBid);
    }

    function ClaimReward() public {
        require(BestBidWallet == _msgSender(), "Only a winner can claim the reward");

        _issueUserReward();
    }

    function _issueUserReward() private {
        if (IsAlive())
            return;

        address bestBidUser = BestBidWallet;

        if (bestBidUser != _bestBidDefault() && (Bids[bestBidUser].CurrentUserBid != 0)) {
            uint96 bidSize = Bids[bestBidUser].CurrentUserBid;
            WithdrawBalance += bidSize;
            Bids[bestBidUser].CurrentUserBid = 0;

            _nftReward().Mint(bestBidUser);        
            
            emit RewardIssued(Bids[bestBidUser].BidTime, bestBidUser, bidSize);
        }
    }

    function _isAlive(uint40 endTime) private view returns (bool) {
        return block.timestamp <= endTime;
        
    }

    function IsAlive() public view returns (bool) {
        return _isAlive(AuctionEndTime);
    }

    function PlaceBid(uint256 bidSize) public {
        require(_msgSender().code.length == 0, "Only EOA can place a bids");
        require(bidSize < type(uint96).max, "bidSize too big");

        uint40 auctionEndTime = AuctionEndTime;
        require(_isAlive(auctionEndTime), "No active auctions");
        require(
            bidSize >= (Bids[BestBidWallet].CurrentUserBid + _bidIncrement()),
            "New bid shall be greater or equal on BidIncrement to current best bid"
        );
        
        AuctionEntry memory userEntry = Bids[_msgSender()];

        int256 transferDelta = int256(bidSize) - int96(userEntry.CurrentUserBid);
        userEntry.BidTime = AuctionStartTime;
        userEntry.CurrentUserBid = uint96(bidSize);

        Bids[_msgSender()] = userEntry;
        BestBidWallet = _msgSender();
        
        if ((auctionEndTime - block.timestamp) < _auctionTimeExtraWindow())
        {
            auctionEndTime = uint40(block.timestamp) + _auctionTimeExtraWindow();
            AuctionEndTime = auctionEndTime;
        }

        if (transferDelta > 0)
            _bidToken().transferFrom(_msgSender(), address(this), uint256(transferDelta));
        else if (transferDelta < 0)
            _bidToken().transfer(_msgSender(), uint256(-transferDelta));

        emit BidPlaced(
                _msgSender(), 
                userEntry.BidTime,
                bidSize,
                auctionEndTime,
                transferDelta
            );
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

        if (userEntry.CurrentUserBid == 0)
            return;

        uint256 repayAmount = userEntry.CurrentUserBid;
        userEntry.CurrentUserBid = 0;
        Bids[_msgSender()] = userEntry;

        _bidToken().transfer(_msgSender(), repayAmount);

        emit RefundClaimed(_msgSender(), auctionStartTime, repayAmount);
    }

}
