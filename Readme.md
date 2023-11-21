**How to build**

1. Install foundry (https://book.getfoundry.sh/)
2. Run `forge build` into root folder. It will generate you output in `out` folder

**How to run tests**

1. Install foundry (https://book.getfoundry.sh/)
2. Fix RPC url in `foundry.toml`
3. Run `forge test` or `forge test -vvv` for detailed output

**Sequence of operation**

Initial:

1. Deploy JoeAuctionsMainnet
2. Deploy JoeMerchNft
3. SetMerchNft
4. SetAuction
5. SetBaseUri

Regular cycles:
1. LaunchAuction
2. PlaceBid
3. ClaimReward/RedeemRefund
4. Withdraw