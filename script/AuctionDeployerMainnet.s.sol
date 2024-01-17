// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";

import {JoeAuctionsMainnet} from "../src/AuctionMainnet.sol";
import {JoeMerchNft} from "../src/JoeMerchNft.sol";

//forge script script/AuctionDeployerMainnet.s.sol:AuctionDeployer --rpc-url URL --broadcast
contract AuctionMainnetDeployer is Script {
    

    function run() public {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address newOwner = 0xaA487E5D595a8A21C43c1Af2ec92d1A657E4A56D;
        address executor = 0xE8e0f775f7006137264E759A4335255B2231D38D;

        address initialOwner = vm.addr(privKey);
        vm.startBroadcast(privKey);

        JoeAuctionsMainnet AuctionContract = new JoeAuctionsMainnet(initialOwner, executor);
        JoeMerchNft MerchNft = new JoeMerchNft(initialOwner);

        AuctionContract.SetMerchNft(address(MerchNft));
        MerchNft.SetAuction(address(AuctionContract));

        //*
        AuctionContract.transferOwnership(newOwner);
        MerchNft.transferOwnership(newOwner);
        //*/

        vm.stopBroadcast();

        vm.startPrank(newOwner);
        AuctionContract.acceptOwnership();
        MerchNft.acceptOwnership();
        vm.stopPrank();
    }
}