// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;


import "forge-std/Test.sol";
import {JoeAuctionsMainnet} from "../src/AuctionMainnet.sol";
import {JoeAuctionsGeneric} from "../src/JoeAuctionsGeneric.sol";
import {IAuction} from "../src/IAuction.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IJoeMerchNft} from "../src/IJoeMerchNft.sol";
import {JoeMerchNft} from "../src/JoeMerchNft.sol";


contract AuctionMainnetTest is Test {

    function setUp() public {
        vm.createSelectFork("ethereum");

        AuctionContract = new JoeAuctionsMainnet(Owner, Executor);
        MerchNft = new JoeMerchNft(Owner);

        vm.startPrank(Owner);
        AuctionContract.SetMerchNft(address(MerchNft));
        MerchNft.SetAuction(address(AuctionContract));
        vm.stopPrank();


        console.log("                     JOE: %s", address(JoeErc20));
        console.log("         AuctionContract: %s", address(AuctionContract));
        console.log("               NFT Merch: %s", address(MerchNft));
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
    JoeMerchNft                        public                 MerchNft;

    //Base set of tests:
    /*
        01. Start auction -> verify state
        02. Start auction, wait expiration -> verify state
        03. Place one bid -> verify user state
        04. Place two bids -> verify users state
        05. Start Auction, Place 3 bid, wait for expire, redeem for lost
        06. Place two bids, increase 2 bids (best first) -> verify users state
        07. Place two bids, increase 2 bids (best last) -> verify users state
        08. Change Owner
        09. Change Executor
        10. Start Auction, Place 2 bid, Try redeem -> 0
        11. Start Auction, Place 3 bid, wait for expire, double issue reward -> check NFT and winner Bid state
        12. NFT Transfer modes
    //*/

    //Access tests
    /*
        Owner:
        A01. SetBidIncrement
        A02. SetAuctionTimeExtraWindow
        A03. SetMerchNft
        A04. SetExecutor
        A05. Multicall
        A06. SetAuction (NFT)
        A07. SetTransferMode (NFT)

        Executor:
        A20. LaunchAuction
        A21. Withdraw

        Auction:
        A40. Mint (NFT)
    //*/

    //Extended tests
    /*
        E1. Start Auction, no action, wait for expire, start new auction -> expect success
        E2. Start Auction, wait less then expire, start new Auction -> expect revert
        E3. Start Auction, no wait, start new Auction -> expect revert
        E4. Start Auction, Try bid less threshold -> expect revert
        E5. Start Auction, Bid User 0, Bid from User 1 less then Bid 0 + increment -> expect revert
        E6. Start Auction, Place 3 bid, wait for expire, start new auction, Place 3 new bids -> verify users states:
            a. re-bids
            b. increase bids
            c. decrease bids
        E7. Start Auction, Place 3 bid, wait for expire, start new auction, Place 2 new bids -> Try redeem -> Only 1 redeem successfull
        E8. Start Auction, wait till AuctionTimeExtraWindow, Place Bid -> check Expiration time
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
        _placeBid(user, size, false);
    }

    function _placeBid(address wallet, uint96 size, bool expectRevert) private {
        console.log();
        console.log("Placing a bid for wallet %s (size: %d [%d])", wallet, size / 1e18, size);

        (uint256 correctedSize, ) = AuctionContract.Bids(wallet);

        if (size > correctedSize)
            correctedSize = size - correctedSize;
        else
            correctedSize = 0;

        if (correctedSize > 0)
        {
            console.log("  Dealing: %d(%d) JOE", correctedSize / 1e18, correctedSize);
            deal(address(JoeErc20), wallet, correctedSize);
        }
        vm.startPrank(wallet);

        if (correctedSize > 0)
            JoeErc20.approve(address(AuctionContract), correctedSize);
        if (expectRevert)
            vm.expectRevert();
        AuctionContract.PlaceBid(size);

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

    function _redeemForUser(address account) private {
        uint256 balanceBefore = JoeErc20.balanceOf(account);

        console.log();
        _printErc20Balances(account);

        vm.startPrank(account);
        AuctionContract.RedeemRefund();
        vm.stopPrank();

        _printErc20Balances(account);
        uint256 balanceAfter = JoeErc20.balanceOf(account);

        console.log("  Redeemed: %d (%d)", (balanceAfter - balanceBefore) / 1e18, balanceAfter - balanceBefore);
        console.log();
    }

    function _checkAuctionLaunchProps() public {
        assertEq(AuctionContract.AuctionEndTime(), block.timestamp + 24 hours);
        assertEq(AuctionContract.AuctionStartTime(), block.timestamp);
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));
        assertEq(AuctionContract.IsAlive(), true);

        (uint96 CurrentUserBid, uint40 BidTime) = AuctionContract.Bids(address(type(uint160).max));

        assertEq(CurrentUserBid, 500 ether);
        assertEq(BidTime, 1);
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

        _checkAuctionLaunchProps();

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

        uint256 auctionStartTime = AuctionContract.AuctionStartTime();

        _printErc20Balances(address(AuctionContract));
        uint256 balanceJoeBefore = JoeErc20.balanceOf(address(AuctionContract));

        _placeBid(Users[0], 1500 ether);

        _printErc20Balances(address(AuctionContract));
        uint256 balanceJoeAfter = JoeErc20.balanceOf(address(AuctionContract));

        assertEq(balanceJoeAfter - balanceJoeBefore, 1500 ether);

        _validateUsersBid(Users[0], auctionStartTime, 1500 ether);
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


        //******************* User 0 *******************/
        (uint96 nextBid, ) = AuctionContract.Bids(AuctionContract.BestBidWallet());
        nextBid += AuctionContract.BidIncrement();


        _placeBid(Users[0], nextBid);

        console.log();
        console.log();
        //******************* User 1 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        nextBid += AuctionContract.BidIncrement();
        _placeBid(Users[1], nextBid);

        console.log();
        console.log();
        //******************* User 2 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        nextBid += AuctionContract.BidIncrement();
        _placeBid(Users[2], nextBid);

        console.log();
        console.log();
    
        //***************** Wait for expiration **************/
        
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1 days / 2);

        console.log("Is alive: %s", AuctionContract.IsAlive());
        assertEq(AuctionContract.IsAlive(), false);

        console.log();
        console.log();

        //***************** Redeem **************/

        uint256[3] memory balancesBefore;
        balancesBefore[0] = JoeErc20.balanceOf(Users[0]);
        balancesBefore[1] = JoeErc20.balanceOf(Users[1]);
        balancesBefore[2] = JoeErc20.balanceOf(Users[2]);

        uint96[3] memory userBidsBefore;

        (userBidsBefore[0], ) = AuctionContract.Bids(Users[0]);
        (userBidsBefore[1], ) = AuctionContract.Bids(Users[1]);
        (userBidsBefore[2], ) = AuctionContract.Bids(Users[2]);

        _redeemForUser(Users[0]);
        _redeemForUser(Users[1]);
        _redeemForUser(Users[2]);

        uint256[3] memory balancesAfter;
        balancesAfter[0] = JoeErc20.balanceOf(Users[0]);
        balancesAfter[1] = JoeErc20.balanceOf(Users[1]);
        balancesAfter[2] = JoeErc20.balanceOf(Users[2]);

        uint96[3] memory userBidsAfter;

        (userBidsAfter[0], ) = AuctionContract.Bids(Users[0]);
        (userBidsAfter[1], ) = AuctionContract.Bids(Users[1]);
        (userBidsAfter[2], ) = AuctionContract.Bids(Users[2]);


        assertGe(balancesAfter[0] - balancesBefore[0], 0);
        assertGe(balancesAfter[1] - balancesBefore[1], 0);
        assertEq(balancesAfter[2] - balancesBefore[2], 0);

        assertNotEq(userBidsBefore[0], userBidsAfter[0]);
        assertNotEq(userBidsBefore[1], userBidsAfter[1]);
        assertEq(userBidsBefore[2], userBidsAfter[2]);


        assertEq(userBidsAfter[0], 0);
        assertEq(userBidsAfter[1], 0);
        assertNotEq(userBidsAfter[2], 0);
        
        _printErc20Balances(address(AuctionContract));
        assertEq(JoeErc20.balanceOf(address(AuctionContract)), nextBid);
    }

    function testCase06() public {
        _launchAuction();

        _printErc20Balances(address(AuctionContract));
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));
        uint256 auctionStartTime = AuctionContract.AuctionStartTime();


        //******************* User 0 *******************/
        (uint96 nextBid, ) = AuctionContract.Bids(AuctionContract.BestBidWallet());
        nextBid += AuctionContract.BidIncrement();


        _placeBid(Users[0], nextBid);
        _printErc20Balances(address(AuctionContract));
        _validateUsersBid(Users[0], auctionStartTime, nextBid);

        console.log();
        console.log();
        //******************* User 1 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        nextBid += AuctionContract.BidIncrement();


        _placeBid(Users[1], nextBid);
        _printErc20Balances(address(AuctionContract));
        _validateUsersBid(Users[1], auctionStartTime, nextBid);


        //******************* User 1 increase *******************/

        (nextBid, ) = AuctionContract.Bids(Users[1]);
        nextBid += AuctionContract.BidIncrement();

        _placeBid(Users[1], nextBid);

        _printErc20Balances(address(AuctionContract));
        _validateUsersBid(Users[1], auctionStartTime, nextBid);
        assertEq(AuctionContract.BestBidWallet(), Users[1]);


        //******************* User 0 increase *******************/

        //(uint96 secondUserBid, ) = AuctionContract.Bids(Users[0]);
        nextBid += AuctionContract.BidIncrement();

        _placeBid(Users[0], nextBid);

        _printErc20Balances(address(AuctionContract));
        _validateUsersBid(Users[0], auctionStartTime, nextBid);
        assertEq(AuctionContract.BestBidWallet(), Users[0]);


        console.log();
        console.log();
    }

    function testCase07() public {
        _launchAuction();

        _printErc20Balances(address(AuctionContract));
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));
        uint256 auctionStartTime = AuctionContract.AuctionStartTime();


        //******************* User 0 *******************/
        (uint96 nextBid, ) = AuctionContract.Bids(AuctionContract.BestBidWallet());
        nextBid += AuctionContract.BidIncrement();


        _placeBid(Users[0], nextBid);
        _printErc20Balances(address(AuctionContract));
        _validateUsersBid(Users[0], auctionStartTime, nextBid);

        console.log();
        console.log();
        //******************* User 1 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        nextBid += AuctionContract.BidIncrement();


        _placeBid(Users[1], nextBid);
        _printErc20Balances(address(AuctionContract));
        _validateUsersBid(Users[1], auctionStartTime, nextBid);


        (nextBid, ) = AuctionContract.Bids(Users[1]);
        //******************* User 0 increase *******************/

        nextBid += AuctionContract.BidIncrement();

        _placeBid(Users[0], nextBid);

        _printErc20Balances(address(AuctionContract));
        _validateUsersBid(Users[0], auctionStartTime, nextBid);
        assertEq(AuctionContract.BestBidWallet(), Users[0]);

        //******************* User 1 increase *******************/

        nextBid += AuctionContract.BidIncrement();

        _placeBid(Users[1], nextBid);

        _printErc20Balances(address(AuctionContract));
        _validateUsersBid(Users[1], auctionStartTime, nextBid);
        assertEq(AuctionContract.BestBidWallet(), Users[1]);


        console.log();
        console.log();
    }

    function testCase08() public {
        address newOwner = address(0x2233009900dead);

        assertEq(AuctionContract.owner(), Owner);


        vm.startPrank(Owner);
        AuctionContract.transferOwnership(newOwner);
        vm.stopPrank();

        assertEq(AuctionContract.owner(), Owner);
        assertEq(AuctionContract.pendingOwner(), newOwner);

        vm.startPrank(newOwner);
        AuctionContract.acceptOwnership();
        vm.stopPrank();

        assertEq(AuctionContract.owner(), newOwner);
        
        vm.startPrank(newOwner);
        AuctionContract.SetBidIncrement(2000 ether);
        vm.stopPrank();
    }

    function testCase09() public {
        address newExecutor = address(0x6688005500dead);

        assertEq(AuctionContract.Executor(), Executor);


        vm.startPrank(Owner);
        AuctionContract.SetExecutor(newExecutor);
        vm.stopPrank();

        assertEq(AuctionContract.Executor(), newExecutor);
        
        vm.startPrank(newExecutor);
        AuctionContract.Withdraw();
        vm.stopPrank();
    }

    function testCase10() public {
        testCase04();

        uint256[2] memory userBalancesBefore;

        userBalancesBefore[0] = JoeErc20.balanceOf(Users[0]);
        userBalancesBefore[1] = JoeErc20.balanceOf(Users[1]);

        _redeemForUser(Users[0]);
        _redeemForUser(Users[1]);

        assertEq(JoeErc20.balanceOf(Users[0]) - userBalancesBefore[0], 0);
        assertEq(JoeErc20.balanceOf(Users[1]) - userBalancesBefore[1], 0);
    }

    function testCase11() public {
        _launchAuction();

        _printErc20Balances(address(AuctionContract));
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));


        //******************* User 0 *******************/
        (uint96 nextBid, ) = AuctionContract.Bids(AuctionContract.BestBidWallet());
        nextBid += AuctionContract.BidIncrement();


        _placeBid(Users[0], nextBid);

        console.log();
        console.log();
        //******************* User 1 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        nextBid += AuctionContract.BidIncrement();
        _placeBid(Users[1], nextBid);

        console.log();
        console.log();
        //******************* User 2 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        nextBid += AuctionContract.BidIncrement();
        _placeBid(Users[2], nextBid);

        console.log();
        console.log();
    
        //***************** Wait for expiration **************/
        
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1 days / 2);

        console.log("Is alive: %s", AuctionContract.IsAlive());
        assertEq(AuctionContract.IsAlive(), false);

        console.log();
        console.log();

        //***************** Reward **************/

        address winnerAddress = AuctionContract.BestBidWallet();
        (uint256 winnerBid, ) = AuctionContract.Bids(winnerAddress);

        assertEq(winnerAddress, Users[2]);
        assertEq(winnerBid, nextBid);

        uint256 lastTokenIdBefore = MerchNft.LastTokenId();

        assertEq(lastTokenIdBefore, 0);
        vm.expectRevert();
        MerchNft.ownerOf(lastTokenIdBefore + 1);

        AuctionContract.ClaimReward();

        assertEq(MerchNft.ownerOf(lastTokenIdBefore + 1), winnerAddress);
        assertEq(MerchNft.LastTokenId(), lastTokenIdBefore + 1);

        (winnerBid, ) = AuctionContract.Bids(winnerAddress);
        assertEq(winnerBid, 0);

        vm.expectRevert();
        MerchNft.ownerOf(lastTokenIdBefore + 2);

        AuctionContract.ClaimReward();
        
        assertEq(MerchNft.LastTokenId(), lastTokenIdBefore + 1);
        vm.expectRevert();
        MerchNft.ownerOf(lastTokenIdBefore + 2);
    }

    function testCase12() public {
        //MerchNft
        //AuctionContract

        vm.startPrank(Owner);
        MerchNft.SetTransferMode(true);
        vm.stopPrank();

        vm.startPrank(address(AuctionContract));
        MerchNft.Mint(Users[0]);
        vm.stopPrank();

        uint256 tokenId = MerchNft.LastTokenId();
        assertEq(MerchNft.ownerOf(tokenId), Users[0]);

        vm.startPrank(Users[0]);
        vm.expectRevert();
        MerchNft.transferFrom(Users[0], Users[1], tokenId);
        vm.stopPrank();

        assertEq(MerchNft.ownerOf(tokenId), Users[0]);
        
        vm.startPrank(Owner);
        MerchNft.SetTransferMode(false);
        vm.stopPrank();

        vm.startPrank(Users[0]);
        MerchNft.transferFrom(Users[0], Users[1], tokenId);
        vm.stopPrank();

        assertEq(MerchNft.ownerOf(tokenId), Users[1]);
    }



    function testCaseA01() public {
        address wrongUser = address(0xdead00dead);

        uint256 initialValue = AuctionContract.BidIncrement();

        vm.startPrank(wrongUser);
        vm.expectRevert();
        AuctionContract.SetBidIncrement(3000 ether);
        vm.stopPrank();

        assertEq(AuctionContract.BidIncrement(), initialValue);

        vm.startPrank(Owner);
        AuctionContract.SetBidIncrement(3500 ether);
        vm.stopPrank();

        assertEq(AuctionContract.BidIncrement(), 3500 ether);
    }

    function testCaseA02() public {
        address wrongUser = address(0xdead00dead);

        uint256 initialValue = AuctionContract.AuctionTimeExtraWindow();

        vm.startPrank(wrongUser);
        vm.expectRevert();
        AuctionContract.SetAuctionTimeExtraWindow(20 minutes);
        vm.stopPrank();

        assertEq(AuctionContract.AuctionTimeExtraWindow(), initialValue);

        vm.startPrank(Owner);
        AuctionContract.SetAuctionTimeExtraWindow(25 minutes);
        vm.stopPrank();

        assertEq(AuctionContract.AuctionTimeExtraWindow(), 25 minutes);
    }

    function testCaseA03() public {
        address wrongUser = address(0xdead00dead);

        address initialValue = AuctionContract.MerchNft();

        vm.startPrank(wrongUser);
        vm.expectRevert();
        AuctionContract.SetMerchNft(address(0xAA0001));
        vm.stopPrank();

        assertEq(AuctionContract.MerchNft(), initialValue);

        vm.startPrank(Owner);
        AuctionContract.SetMerchNft(address(0xAA0002));
        vm.stopPrank();

        assertEq(AuctionContract.MerchNft(), address(0xAA0002));
    }

    function testCaseA04() public {
        address wrongUser = address(0xdead00dead);

        address initialValue = AuctionContract.Executor();

        vm.startPrank(wrongUser);
        vm.expectRevert();
        AuctionContract.SetExecutor(address(0xAA0001));
        vm.stopPrank();

        assertEq(AuctionContract.Executor(), initialValue);

        vm.startPrank(Owner);
        AuctionContract.SetExecutor(address(0xAA0002));
        vm.stopPrank();

        assertEq(AuctionContract.Executor(), address(0xAA0002));
    }

    function testCaseA05() public {
        address wrongUser = address(0xdead00dead);

        deal(address(JoeErc20), address(AuctionContract), 1e15);
        deal(address(AuctionContract),                    1e16);


        address[] memory targets = new address[](2);        
        uint256[] memory values  = new uint256[](2);
        bytes[] memory calldatas =   new bytes[](2);

        address receiver = address(0xBB00CC);

        targets[0] = address(JoeErc20);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", receiver, 1e15);
        
        targets[1] = receiver;
        values[1] = 1e16;
        calldatas[1] = new bytes(0);

        vm.startPrank(wrongUser);
        vm.expectRevert();
        AuctionContract.Multicall(targets, values, calldatas);
        vm.stopPrank();

        assertEq(JoeErc20.balanceOf(receiver), 0);
        assertEq(receiver.balance,             0);

        vm.startPrank(Owner);
        AuctionContract.Multicall(targets, values, calldatas);
        vm.stopPrank();

        assertEq(JoeErc20.balanceOf(receiver), 1e15);
        assertEq(receiver.balance,             1e16);
    }


    function testCaseA06() public {
        address wrongUser = address(0xdead00dead);

        address initialValue = MerchNft.Auction();

        vm.startPrank(wrongUser);
        vm.expectRevert();
        MerchNft.SetAuction(address(0x09080706050403020100));
        vm.stopPrank();

        assertEq(MerchNft.Auction(), initialValue);

        vm.startPrank(Owner);
        MerchNft.SetAuction(address(0x09080706050403020100));
        vm.stopPrank();

        assertEq(MerchNft.Auction(), address(0x09080706050403020100));
    }
    
    function testCaseA07() public {
        address wrongUser = address(0xdead00dead);

        bool initialValue = MerchNft.TransferDisabled();

        vm.startPrank(wrongUser);
        vm.expectRevert();
        MerchNft.SetTransferMode(!initialValue);
        vm.stopPrank();

        assertEq(MerchNft.TransferDisabled(), initialValue);

        vm.startPrank(Owner);
        MerchNft.SetTransferMode(!initialValue);
        vm.stopPrank();

        assertEq(MerchNft.TransferDisabled(), !initialValue);
    }



    function testCaseA20() public {
        address wrongUser = address(0xdead00dead);

        uint256 initialValue = AuctionContract.AuctionEndTime();

        vm.startPrank(wrongUser);
        vm.expectRevert();
        AuctionContract.LaunchAuction(uint40(block.timestamp + 1 hours), 500 ether);
        vm.stopPrank();

        assertEq(AuctionContract.AuctionEndTime(), initialValue);

        vm.startPrank(Executor);
        AuctionContract.LaunchAuction(uint40(block.timestamp + 1 hours), 500 ether);
        vm.stopPrank();

        assertEq(AuctionContract.AuctionEndTime(), block.timestamp + 1 hours);
    }

    function testCaseA21() public {
        testCase03();
        (uint256 user0Bid, ) = AuctionContract.Bids(Users[0]);
        
        vm.warp(block.timestamp + 1 days + 2 seconds);
        vm.roll(block.number + (1 days + 2 seconds) / 2);
        AuctionContract.ClaimReward();


        address wrongUser = address(0xdead00dead);
        uint256 initialValue = JoeErc20.balanceOf(Owner);

        vm.startPrank(wrongUser);
        vm.expectRevert();
        AuctionContract.Withdraw();
        vm.stopPrank();

        assertEq(JoeErc20.balanceOf(Owner) - initialValue, 0);

        vm.startPrank(Executor);
        AuctionContract.Withdraw();
        vm.stopPrank();

        assertEq(JoeErc20.balanceOf(Owner) - initialValue, user0Bid);
    }


    
    function testCaseA40() public {
        address wrongUser = address(0xdead00dead);

        uint256 initialValue = MerchNft.LastTokenId();

        vm.startPrank(wrongUser);
        vm.expectRevert();
        MerchNft.Mint(address(0x020100));
        vm.stopPrank();

        assertEq(MerchNft.LastTokenId(), initialValue);

        vm.startPrank(address(AuctionContract));
        MerchNft.Mint(address(0x020100));
        vm.stopPrank();

        assertEq(MerchNft.LastTokenId(), initialValue + 1);
    }

    function testCaseE1() public {
        assertEq(AuctionContract.AuctionEndTime(), 0);
        assertEq(AuctionContract.AuctionStartTime(), 0);
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));
        assertEq(AuctionContract.IsAlive(), false);

        (uint96 CurrentUserBid, uint40 BidTime) = AuctionContract.Bids(address(type(uint160).max));

        assertEq(CurrentUserBid, 0);
        assertEq(BidTime, 1);

        _launchAuction();

        _checkAuctionLaunchProps();

        vm.warp(block.timestamp + 1 days + 1 minutes);
        vm.roll(block.number + (1 days + 1 minutes) / 2);

        console.log("Is alive: %s", AuctionContract.IsAlive());
        assertEq(AuctionContract.IsAlive(), false);

        _launchAuction();

        _checkAuctionLaunchProps();
    }

    function testCaseE2() public {
        assertEq(AuctionContract.AuctionEndTime(), 0);
        assertEq(AuctionContract.AuctionStartTime(), 0);
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));
        assertEq(AuctionContract.IsAlive(), false);

        (uint96 CurrentUserBid, uint40 BidTime) = AuctionContract.Bids(address(type(uint160).max));

        assertEq(CurrentUserBid, 0);
        assertEq(BidTime, 1);

        _launchAuction();

        _checkAuctionLaunchProps();

        vm.warp(block.timestamp + 1 days );
        vm.roll(block.number + 1 days / 2);

        console.log("Is alive: %s", AuctionContract.IsAlive());
        assertEq(AuctionContract.IsAlive(), true);

        console.log();
        console.log("Launchin new auction at %d", block.timestamp);
        
        vm.startPrank(Executor);
        vm.expectRevert();
        AuctionContract.LaunchAuction(uint40(block.timestamp + 1 days), 500 ether);
        vm.stopPrank();


        console.log("Auction has been launched");
        console.log();
    }

    function testCaseE3() public {
        assertEq(AuctionContract.AuctionEndTime(), 0);
        assertEq(AuctionContract.AuctionStartTime(), 0);
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));
        assertEq(AuctionContract.IsAlive(), false);

        (uint96 CurrentUserBid, uint40 BidTime) = AuctionContract.Bids(address(type(uint160).max));

        assertEq(CurrentUserBid, 0);
        assertEq(BidTime, 1);

        _launchAuction();

        _checkAuctionLaunchProps();

        console.log("Is alive: %s", AuctionContract.IsAlive());
        assertEq(AuctionContract.IsAlive(), true);

        console.log();
        console.log("Launchin new auction at %d", block.timestamp);
        
        vm.startPrank(Executor);
        vm.expectRevert();
        AuctionContract.LaunchAuction(uint40(block.timestamp + 1 days), 500 ether);
        vm.stopPrank();


        console.log("Auction has been launched");
        console.log();
    }

    function testCaseE4() public {
        _launchAuction();

        _printErc20Balances(address(AuctionContract));

        uint256 balanceJoeBefore = JoeErc20.balanceOf(address(AuctionContract));

        _placeBid(Users[0], 1500 ether - 1, true);

        _printErc20Balances(address(AuctionContract));
        uint256 balanceJoeAfter = JoeErc20.balanceOf(address(AuctionContract));        
        (uint96 CurrentUserBid, ) = AuctionContract.Bids(Users[0]);


        assertEq(balanceJoeAfter - balanceJoeBefore, 0);
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));
        assertEq(CurrentUserBid, 0);
    }

    
    function testCaseE5() public {
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

        nextBid += AuctionContract.BidIncrement() - 1;
        _placeBid(Users[1], nextBid, true);
        _printErc20Balances(address(AuctionContract));

        balanceJoeAfter = JoeErc20.balanceOf(address(AuctionContract));

        assertEq(balanceJoeAfter - balanceJoeBefore, 0);
        assertEq(AuctionContract.BestBidWallet(), Users[0]);
    }

    struct CaseE6State {
        uint96[3] firstBids;
        uint256 secondAuctionLaunchTime;
        uint256 balanceJoeBefore;
    }

    function _caseE6Core(CaseE6State memory state, uint96 extraTokens) private {
        _launchAuction();

        state.balanceJoeBefore = JoeErc20.balanceOf(address(AuctionContract));
        uint256 firstAuctionLaunchTime = AuctionContract.AuctionStartTime();
        _printErc20Balances(address(AuctionContract));
        assertEq(AuctionContract.BestBidWallet(), address(type(uint160).max));


        //******************* User 0 *******************/
        (uint96 nextBid, ) = AuctionContract.Bids(AuctionContract.BestBidWallet());
        nextBid += AuctionContract.BidIncrement() + extraTokens;
        state.firstBids[0] = nextBid;


        _placeBid(Users[0], nextBid);

        console.log();
        console.log();
        //******************* User 1 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        nextBid += AuctionContract.BidIncrement();
        state.firstBids[1] = nextBid;

        _placeBid(Users[1], nextBid);

        console.log();
        console.log();
        //******************* User 2 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        nextBid += AuctionContract.BidIncrement();
        state.firstBids[2] = nextBid;

        _placeBid(Users[2], nextBid);

        console.log();
        console.log();
    
        //***************** Wait for expiration **************/
        
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1 days / 2);

        console.log("Is alive: %s", AuctionContract.IsAlive());
        assertEq(AuctionContract.IsAlive(), false);

        console.log();
        console.log();

        //***************** New round **************/

        _launchAuction();
        state.secondAuctionLaunchTime = AuctionContract.AuctionStartTime();

        _checkAuctionLaunchProps();

        assertNotEq(firstAuctionLaunchTime, state.secondAuctionLaunchTime);
    }

    function testCaseE6A() public {
        CaseE6State memory state;

        _caseE6Core(state, 0);
       
        //******************* User 0 *******************/
        _placeBid(Users[0], uint96(state.firstBids[0]));

        assertEq(AuctionContract.BestBidWallet(), Users[0]);
        _validateUsersBid(Users[0], state.secondAuctionLaunchTime, state.firstBids[0]);

        console.log();
        console.log();
        //******************* User 1 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        _placeBid(Users[1], uint96(state.firstBids[1]));

        assertEq(AuctionContract.BestBidWallet(), Users[1]);
        _validateUsersBid(Users[1], state.secondAuctionLaunchTime, state.firstBids[1]);

        console.log();
        console.log();
        //******************* User 2 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        uint96 nextBid = state.firstBids[1] + AuctionContract.BidIncrement();
        _placeBid(Users[2], nextBid);

        assertEq(AuctionContract.BestBidWallet(), Users[2]);
        _validateUsersBid(Users[2], state.secondAuctionLaunchTime, nextBid);

        uint256 balanceJoeAfter = JoeErc20.balanceOf(address(AuctionContract));
        assertEq(
            balanceJoeAfter - state.balanceJoeBefore, 
            nextBid + 
                state.firstBids[0] + state.firstBids[1] + state.firstBids[2]
        );

        console.log();
        console.log();
    }

    function testCaseE6B() public {
        CaseE6State memory state;

        _caseE6Core(state, 0);
       
        //******************* User 0 *******************/
        uint96 delta = 10 ether;
        _placeBid(Users[0], uint96(state.firstBids[0]) + delta);

        assertEq(AuctionContract.BestBidWallet(), Users[0]);
        _validateUsersBid(Users[0], state.secondAuctionLaunchTime, state.firstBids[0] + delta);

        console.log();
        console.log();
        //******************* User 1 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        delta += 25 ether;

        _placeBid(Users[1], uint96(state.firstBids[1]) + delta);

        assertEq(AuctionContract.BestBidWallet(), Users[1]);
        _validateUsersBid(Users[1], state.secondAuctionLaunchTime, state.firstBids[1] + delta);

        console.log();
        console.log();
        //******************* User 2 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        delta += 400 ether;


        uint96 nextBid = state.firstBids[1] + AuctionContract.BidIncrement() + delta;
        _placeBid(Users[2], nextBid);

        assertEq(AuctionContract.BestBidWallet(), Users[2]);
        _validateUsersBid(Users[2], state.secondAuctionLaunchTime, nextBid);

        uint256 balanceJoeAfter = JoeErc20.balanceOf(address(AuctionContract));
        assertEq(
            balanceJoeAfter - state.balanceJoeBefore, 
            nextBid + 
                state.firstBids[0] + state.firstBids[1] + state.firstBids[2]
                + 2 * 10 ether + 25 ether
        );

        console.log();
        console.log();
    }

    function testCaseE6C() public {
        CaseE6State memory state;

        _caseE6Core(state, 100 ether);
       
        //******************* User 0 *******************/
        uint96 delta = 18 ether;
        _placeBid(Users[0], uint96(state.firstBids[0]) - delta);

        assertEq(AuctionContract.BestBidWallet(), Users[0]);
        _validateUsersBid(Users[0], state.secondAuctionLaunchTime, state.firstBids[0] - delta);
        _printErc20Balances(Users[0]);
        assertEq(JoeErc20.balanceOf(Users[0]), delta);

        console.log();
        console.log();
        //******************* User 1 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        delta = 10 ether;

        _placeBid(Users[1], uint96(state.firstBids[1]) - delta);

        assertEq(AuctionContract.BestBidWallet(), Users[1]);
        _validateUsersBid(Users[1], state.secondAuctionLaunchTime, state.firstBids[1] - delta);
        _printErc20Balances(Users[1]);
        assertEq(JoeErc20.balanceOf(Users[1]), delta);

        console.log();
        console.log();
        //******************* User 2 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        delta = 5 ether;


        uint96 nextBid = state.firstBids[1] + AuctionContract.BidIncrement() - delta;
        _placeBid(Users[2], nextBid);

        assertEq(AuctionContract.BestBidWallet(), Users[2]);
        _validateUsersBid(Users[2], state.secondAuctionLaunchTime, nextBid);
        _printErc20Balances(Users[2]);
        assertEq(JoeErc20.balanceOf(Users[2]), 0);

        uint256 balanceJoeAfter = JoeErc20.balanceOf(address(AuctionContract));
        assertEq(
            balanceJoeAfter - state.balanceJoeBefore, 
            nextBid + 
                state.firstBids[0] + state.firstBids[1] + state.firstBids[2]
                - 18 ether - 10 ether
        );

        console.log();
        console.log();
    }


    function testCaseE7() public {
        CaseE6State memory state;

        _caseE6Core(state, 0);
       
        //******************* User 0 *******************/
        /*
        _placeBid(Users[0], uint96(state.firstBids[0]));

        assertEq(AuctionContract.BestBidWallet(), Users[0]);
        _validateUsersBid(Users[0], state.secondAuctionLaunchTime, state.firstBids[0]);

        console.log();
        console.log();
        //*/
        //******************* User 1 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        _placeBid(Users[1], uint96(state.firstBids[1]));

        assertEq(AuctionContract.BestBidWallet(), Users[1]);
        _validateUsersBid(Users[1], state.secondAuctionLaunchTime, state.firstBids[1]);

        console.log();
        console.log();
        //******************* User 2 *******************/

        vm.warp(block.timestamp + 1 minutes);
        vm.roll(block.number + 1 minutes / 2);

        uint96 nextBid = state.firstBids[1] + AuctionContract.BidIncrement();
        _placeBid(Users[2], nextBid);

        assertEq(AuctionContract.BestBidWallet(), Users[2]);
        _validateUsersBid(Users[2], state.secondAuctionLaunchTime, nextBid);

        /****************** Redeem User 0 *****************/

        uint256 userBalanceBefore = JoeErc20.balanceOf(Users[0]);
        _redeemForUser(Users[0]);
        assertEq(JoeErc20.balanceOf(Users[0]) - userBalanceBefore, state.firstBids[0]);

        /****************** Redeem User 1 *****************/

        userBalanceBefore = JoeErc20.balanceOf(Users[1]);
        _redeemForUser(Users[1]);
        assertEq(JoeErc20.balanceOf(Users[1]) - userBalanceBefore, 0);

        /****************** Redeem User 2 *****************/

        userBalanceBefore = JoeErc20.balanceOf(Users[2]);
        _redeemForUser(Users[2]);
        assertEq(JoeErc20.balanceOf(Users[2]) - userBalanceBefore, 0);

        /****************** Final check *******************/
        uint256 balanceJoeAfter = JoeErc20.balanceOf(address(AuctionContract));
        assertEq(
            balanceJoeAfter - state.balanceJoeBefore, 
            nextBid + 
                state.firstBids[1] + state.firstBids[2]
        );

        console.log();
        console.log();
    }

    function testCaseE8() public {
        _launchAuction();

        uint256 extraTimeWnd = AuctionContract.AuctionTimeExtraWindow();
        //uint256 oldExpirationTime = AuctionContract.AuctionEndTime();

        vm.warp(block.timestamp + 1 days - (extraTimeWnd / 2));
        vm.roll(block.number + (1 days - (extraTimeWnd / 2)) / 2);
        
        _placeBid(Users[0], 1500 ether);

        uint256 newExpirationTime = AuctionContract.AuctionEndTime();

        assertEq(newExpirationTime, block.timestamp + extraTimeWnd);
    }
}