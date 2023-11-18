// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;


import "forge-std/Test.sol";
import {JoeAuctionsMainnet} from "../src/AuctionMainnet.sol";
import {JoeAuctionsGeneric} from "../src/AuctionGenericV1.sol";
import {IAuction} from "../src/IAuction.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


contract AuctionMainnetTest is Test {

    function setUp() public {
        vm.createSelectFork("ethereum");

        AuctionContract = new JoeAuctionsMainnet(Owner, Executor);


        console.log("                     JOE: %s", address(JoeErc20));
        console.log("         AuctionContract: %s", address(AuctionContract));
    }

    JoeAuctionsMainnet                 public                 AuctionContract;
    address                            public                 Owner               = address(uint160(0xAABBCC0000));
    address                            public                 Executor            = address(uint160(0xFFDDEE0002));
    address[3]                         public                 Users               = [
                                                                                        address(uint160(0xCC00220001)),
                                                                                        address(uint160(0xCC00220002)),
                                                                                        address(uint160(0xCC00220003))
                                                                                    ];
    //
    IERC20                             public                 JoeErc20            = IERC20(0x76e222b07C53D28b89b0bAc18602810Fc22B49A8);

    //Base set of tests:
    /*
        01. Start auction -> verify state
        02. Start auction, wait expiration -> verify state
        03. Place one bid -> verify user state
        04. Place two bids -> verify users state
        05. Start Auction, Place 3 bid, wait for expire, redeem for lost
        06. Start Auction, Place 3 bid, wait for expire, start new auction, Place 3 new bids -> verify users states
        07. Place two bids, increase 2 bids (best first) -> verify users state
        08. Place two bids, increase 2 bids (best last) -> verify users state
        09. Change Owner
        10. Change Executor
        11. Multicall test
    //*/

    //Extended tests
    /*
        E1. Start Auction, no action, wait for expire, start new auction -> expect success
        E2. Start Auction, wait less then expire, start new Auction -> expect revert
        E3. Start Auction, no wait, start new Auction -> expect revert

        //Access tests

        //Overflow tests?AuctionGeneric
    //*/

    function _launchAuction() private {
        console.log();
        console.log("Launchin new auction at %d", block.timestamp);
        
        vm.startPrank(Executor);
        AuctionContract.LaunchAuction(uint40(block.timestamp + 1 days), 500 ether);
        vm.stopPrank();


        console.log("Auction has been launched");
        console.log();
    }

    function _placeBid(address user, uint96 size) private {
        deal(address(JoeErc20), user, size);

        console.log();
        console.log("Placing a bid for user %s (size: %d [%d])", user, size / 1e18, size);
        vm.startPrank(user);

        JoeErc20.approve(address(AuctionContract), size);
        AuctionContract.IncreaseBid(size);

        vm.stopPrank();
        
        console.log("Bid has been placed");
        console.log();
    }

    function _printErc20Balances(address account) private view {
        console.log(" Balances for %s", account);

        uint256 balance = JoeErc20.balanceOf(account);
        console.log("     JOE: %d (%d)", balance/1e18, balance);
    }

    function _validateUsersBid(address wallet, uint256 launchTime, uint256 bidSize) private {
        
        console.log();
        console.log("Bid for user %s:", wallet);
        (uint96 CurrentUserBid, uint40 BidTime) = AuctionContract.Bids(wallet);

        console.log("    CurrentUserBid: %d (%d)", CurrentUserBid /1e18, CurrentUserBid);
        console.log("           BidTime: %d", BidTime);
        console.log();

        assertEq(CurrentUserBid, bidSize);
        assertEq(BidTime, launchTime);
    }

    function testCase01() public {
        assertEq(AuctionContract.AuctionEndTime(), 0);
        assertEq(AuctionContract.AuctionStartTime(), 0);
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));
        assertEq(AuctionContract.IsAlive(), false);

        (uint96 CurrentUserBid, uint40 BidTime) = AuctionContract.Bids(address(type(uint160).max));

        assertEq(CurrentUserBid, 0);
        assertEq(BidTime, 1);

        _launchAuction();

        assertEq(AuctionContract.AuctionEndTime(), block.timestamp + 24 hours);
        assertEq(AuctionContract.AuctionStartTime(), block.timestamp);
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));
        assertEq(AuctionContract.IsAlive(), true);

        (CurrentUserBid, BidTime) = AuctionContract.Bids(address(type(uint160).max));

        assertEq(CurrentUserBid, 500 ether);
        assertEq(BidTime, 1);

        console.log("test passed");
    }

    function testCase02() public {
        _launchAuction();


        vm.warp(block.timestamp + (1 days - 1));
        vm.roll(block.number + 1 days / 2);

        
        assertEq(AuctionContract.IsAlive(), true);
        console.log("1 day - 1 second .... OK");
        
        vm.warp(block.timestamp + 1);

        assertEq(AuctionContract.IsAlive(), true);
        console.log("1 day            .... OK");

        vm.warp(block.timestamp + 1);

        assertEq(AuctionContract.IsAlive(), false); 
        console.log("1 day + 1 second .... OK");
    }

    function testCase03() public {
        _launchAuction();

        _printErc20Balances(address(AuctionContract));

        uint256 balanceJoeBefore = JoeErc20.balanceOf(address(AuctionContract));

        _placeBid(Users[0], 1500 ether);

        _printErc20Balances(address(AuctionContract));
        uint256 balanceJoeAfter = JoeErc20.balanceOf(address(AuctionContract));

        assertEq(balanceJoeAfter - balanceJoeBefore, 1500 ether);
    }

    function testCase04() public {
        _launchAuction();

        _printErc20Balances(address(AuctionContract));
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));
        uint256 auctionStartTime = AuctionContract.AuctionStartTime();


        //******************* User 0 *******************/
        uint256 balanceJoeBefore = JoeErc20.balanceOf(address(AuctionContract));
        (uint96 nextBid, ) = AuctionContract.Bids(AuctionContract.BestBidWallet());
        nextBid += AuctionContract.BidIncrement();


        _placeBid(Users[0], nextBid);

        _printErc20Balances(address(AuctionContract));
        uint256 balanceJoeAfter = JoeErc20.balanceOf(address(AuctionContract));

        assertEq(balanceJoeAfter - balanceJoeBefore, nextBid);
        assertEq(AuctionContract.BestBidWallet(), Users[0]);

        _validateUsersBid(Users[0], auctionStartTime, nextBid);

        console.log();
        console.log();
        //******************* User 1 *******************/

        balanceJoeBefore = balanceJoeAfter;
        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        nextBid += AuctionContract.BidIncrement();
        _placeBid(Users[1], nextBid);
        _printErc20Balances(address(AuctionContract));

        balanceJoeAfter = JoeErc20.balanceOf(address(AuctionContract));

        assertEq(balanceJoeAfter - balanceJoeBefore, nextBid);
        assertEq(AuctionContract.BestBidWallet(), Users[1]);
        _validateUsersBid(Users[1], auctionStartTime, nextBid);
    }

    function testCase05() public {
        _launchAuction();

        _printErc20Balances(address(AuctionContract));
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));
        uint256 auctionStartTime = AuctionContract.AuctionStartTime();


        //******************* User 0 *******************/
        uint256 balanceJoeBefore = JoeErc20.balanceOf(address(AuctionContract));
        (uint96 nextBid, ) = AuctionContract.Bids(AuctionContract.BestBidWallet());
        nextBid += AuctionContract.BidIncrement();


        _placeBid(Users[0], nextBid);

        _printErc20Balances(address(AuctionContract));
        uint256 balanceJoeAfter = JoeErc20.balanceOf(address(AuctionContract));

        assertEq(balanceJoeAfter - balanceJoeBefore, nextBid);
        assertEq(AuctionContract.BestBidWallet(), Users[0]);

        _validateUsersBid(Users[0], auctionStartTime, nextBid);

        console.log();
        console.log();
        //******************* User 1 *******************/

        balanceJoeBefore = balanceJoeAfter;
        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        nextBid += AuctionContract.BidIncrement();
        _placeBid(Users[1], nextBid);
        _printErc20Balances(address(AuctionContract));

        balanceJoeAfter = JoeErc20.balanceOf(address(AuctionContract));

        assertEq(balanceJoeAfter - balanceJoeBefore, nextBid);
        assertEq(AuctionContract.BestBidWallet(), Users[1]);
        _validateUsersBid(Users[1], auctionStartTime, nextBid);
    }
}