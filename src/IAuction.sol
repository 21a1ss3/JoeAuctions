// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAuction { 
    //Total supply is 1b *10^18. log_2 (1b *10^18) < 90

    struct AuctionEntry {
        uint96 CurrentUserBid;
        uint40  BidTime;
    }

    /// @notice Claims a reward for a winner
    /// @dev Claims a reward for a winner
    function ClaimReward() external;

    /// @notice Returns a current state of Auction
    /// @dev Returns a current state of Auction
    /// @return bool true if auction is active, false - otherwise
    function IsAlive() external view returns (bool);

    /// @notice Placing a new bid or resizing user bid
    /// @dev Placing a new bid or resizing user bid
    /// @param bidSize New absolute size of user Bid
    function PlaceBid(uint256 bidSize) external;

    /// @notice Refunds outbid users
    /// @dev Refunds outbid users
    function RedeemRefund() external;

    
    /// @notice Returns current bid increment required to outbid previous user
    /// @dev Returns current bid increment required to outbid previous user
    /// @return uint96 bid increment
    function BidIncrement() external view returns (uint96);
    
    /// @notice Returns current auction time window when end time is extended
    /// @dev Returns current auction time window when end time is extended
    /// @return uint40 auction time window
    function AuctionTimeExtraWindow() external view returns (uint40);
    
    /// @notice Returns current Joe Merch NFT contract used to reward user
    /// @dev Returns current Joe Merch NFT contract used to reward user
    /// @return address Address of Joe Merch NFT contract
    function MerchNft() external view returns (address);
    
    /// @notice Returns timestamp when current Auction stops(-ed), inclusive
    /// @dev Returns timestamp when current Auction stops(-ed), inclusive
    /// @return uint40 Auction end time (same units as block.timestamp)
    function AuctionEndTime() external view returns (uint40);
    
    /// @notice Returns time when current Auction has been launched
    /// @dev Returns time when current Auction has been launched
    /// @return uint40 Auction start time (same units as block.timestamp)
    function AuctionStartTime() external view returns (uint40);
    
    /// @notice Returns current best bid wallet -or- 0xfffff..fff
    /// @dev Returns current best bid wallet -or- 0xfffff..fff
    /// @return address Current best bid wallet
    function BestBidWallet() external view returns (address);
    
    /// @notice Returns status of user's Bid
    /// @dev Returns status of user's Bid
    /// @return CurrentUserBid Current user's bid size
    /// @return BidTime Auction start timestamp described associated auction
    function Bids(address wallet) external view returns (uint96 CurrentUserBid, uint40 BidTime);

    event AuctionLaunched(
        uint256 indexed StartTime,
        uint256 indexed EndTime,
        uint256 StartBid
    );

    event RewardIssued(
        uint256 indexed AuctionStartTime,
        address indexed Wallet,
        uint256 indexed BidSize
    );

    event BidPlaced(
        address indexed Wallet,
        uint256 indexed AuctionStartTime,
        uint256 Size,
        uint256 AuctionEndTime,
        int256 Transferred
    );

    event RefundClaimed(
        address indexed Wallet,
        uint256 indexed AuctionStartTime,
        uint256 Size
    );
}