// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract ProportionalStaking is Ownable {

    using SafeERC20 for IERC20;

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    uint256 public rewardPerSecond;
    uint256 public accRewardPerShare;
    uint256 public lastUpdateTime;
    uint256 public totalStaked;

    uint256 private constant PRECISION = 1e18;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => UserInfo) public userInfo;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardPerSecondUpdated(uint256 rewardPerSecond_);


    constructor(address stakingToken_, address rewardToken_, uint256 rewardPerSecond_, address owner_) Ownable(owner_) {
        stakingToken = IERC20(stakingToken_);
        rewardToken = IERC20(rewardToken_);
        rewardPerSecond = rewardPerSecond_;
        lastUpdateTime = block.timestamp;
    }

    function stake(uint256 amount_) external {
        require(amount_ > 0, "Cannot stake 0.");

        _updateReward();

        // pay rewards to user first
        UserInfo storage user = userInfo[msg.sender];
        if(user.amount > 0) {
            uint256 pending_ = (user.amount * accRewardPerShare / PRECISION) - user.rewardDebt;
            if(pending_ > 0) {
                rewardToken.safeTransfer(msg.sender, pending_);
            }
        }

        // move tokens - transfer
        stakingToken.safeTransferFrom(msg.sender, address(this), amount_);

        // update state
        user.amount += amount_;
        totalStaked += amount_;

        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

        emit Staked(msg.sender, amount_);
    }

    function unstake(uint256 amount_) external {
        UserInfo storage user = userInfo[msg.sender];
        require(amount_ <= user.amount, "Not enough tokens.");

        _updateReward();

        uint256 pending_ = (user.amount * accRewardPerShare / PRECISION) - user.rewardDebt;
        if(pending_ > 0) {
            rewardToken.safeTransfer(msg.sender, pending_);
        }

        user.amount -= amount_;
        stakingToken.safeTransfer(msg.sender, amount_);
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;


        emit Unstaked(msg.sender, amount_);
    }

    function claimRewards() external {
        UserInfo storage user = userInfo[msg.sender];
        _updateReward();
        uint256 pending_ = (user.amount * accRewardPerShare / PRECISION) - user.rewardDebt;
        
        require(pending_ > 0, "Nothing to claim.");
        rewardToken.safeTransfer(msg.sender, pending_);

        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

        emit RewardClaimed(msg.sender, pending_);
    }

    function setRewardPerSecond(uint256 rewardPerSecond_) external onlyOwner {
        _updateReward();
        rewardPerSecond = rewardPerSecond_;
        emit RewardPerSecondUpdated(rewardPerSecond_);
    }

    function _updateReward() internal {        
        if(totalStaked > 0) {
            uint256 elapsed_ = block.timestamp - lastUpdateTime;
            accRewardPerShare += (elapsed_ * rewardPerSecond * PRECISION) / totalStaked;
        }        
        lastUpdateTime = block.timestamp;
    }

}