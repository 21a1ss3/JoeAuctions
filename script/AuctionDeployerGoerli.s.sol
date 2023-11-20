// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";

import {JoeAuctionsGoerli} from "../src/AuctionGoerli.sol";
import {JoeMerchNft} from "../src/JoeMerchNft.sol";

//forge script script/AuctionDeployerGoerli.s.sol:AuctionDeployer --rpc-url URL --broadcast -vvvv
contract AuctionDeployer is Script {
    

    function run() public {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address owner = 0x9d7B5dCab45522EA557543236DF15A762483372c;

        vm.startBroadcast(privKey);

        JoeAuctionsGoerli AuctionContract = new JoeAuctionsGoerli(owner, owner);
        JoeMerchNft MerchNft = new JoeMerchNft(owner);

        AuctionContract.SetMerchNft(address(MerchNft));
        MerchNft.SetAuction(address(AuctionContract));

        vm.stopBroadcast();
    }
}