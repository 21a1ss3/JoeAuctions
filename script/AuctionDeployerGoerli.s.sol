// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";

import {JoeAuctionsGoerli} from "../src/AuctionGoerli.sol";
import {JoeMerchNft} from "../src/JoeMerchNft.sol";

//forge script script/AuctionDeployerGoerli.s.sol:AuctionDeployer --rpc-url URL --broadcast -vvvv
contract AuctionDeployer is Script {
    

    function run() public {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address initialOwner = 0x9d7B5dCab45522EA557543236DF15A762483372c;
        address newOwner = 0xaA487E5D595a8A21C43c1Af2ec92d1A657E4A56D;
        address executor = 0xE8e0f775f7006137264E759A4335255B2231D38D;

        vm.startBroadcast(privKey);

        JoeAuctionsGoerli AuctionContract = new JoeAuctionsGoerli(initialOwner, executor);
        JoeMerchNft MerchNft = new JoeMerchNft(initialOwner);

        AuctionContract.SetMerchNft(address(MerchNft));
        MerchNft.SetAuction(address(AuctionContract));

        AuctionContract.transferOwnership(newOwner);
        MerchNft.transferOwnership(newOwner);

        vm.stopBroadcast();
    }
}