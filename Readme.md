**How to build**

1. Install foundry (https://book.getfoundry.sh/)
2. Run `forge build` into root folder. It will generate you output in out folder

**Sequence of operation**
Initial:

1. Deploy JoeAuctionsMainnet
2. Deploy JoeMerchNft
3. SetMerchNft
4. SetAuction

Regular cycles:
1. LaunchAuction
2. PlaceBid
3. ClaimReward/RedeemRefund
4. Withdraw