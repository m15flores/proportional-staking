// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

import "forge-std/Test.sol";
import "../src/ProportionalStaking.sol";
import "./mocks/MockToken.sol";
import "../src/RewardToken.sol";

contract ProportionalStakingTest is Test {

    ProportionalStaking public proportionalStaking;
    MockToken public mockToken;
    RewardToken public rewardToken;

    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 constant REWARD_FUNDING = 200_000 ether;
    uint256 constant MOCK_TOKEN_FUNDING = 1_000 ether;

    uint256 rewardPerSecond;
    address owner;
    address randomUser;
    address secondRandomUser;
    
    function setUp() public {
        mockToken = new MockToken();
        owner = makeAddr("owner");
        randomUser = makeAddr("randomUser");
        secondRandomUser = makeAddr("secondRandomUser");
        rewardPerSecond = 50;

        rewardToken = new RewardToken(INITIAL_SUPPLY);
        
        proportionalStaking = new ProportionalStaking(address(mockToken), address(rewardToken), rewardPerSecond, owner);

        rewardToken.transfer(address(proportionalStaking), REWARD_FUNDING);
        mockToken.transfer(randomUser, MOCK_TOKEN_FUNDING);
        mockToken.transfer(secondRandomUser, MOCK_TOKEN_FUNDING);   
    }

    // Stake tests

    function test_Stake() public {
        uint256 stakeAmount_ = 100 ether;

        vm.startPrank(randomUser);
        
        (uint256 randomUserStakedBeforeStake, ) = proportionalStaking.userInfo(randomUser);
        uint256 totalStakedBeforeStake = proportionalStaking.totalStaked();
        uint256 randomUserMockTokenBeforeStake = mockToken.balanceOf(randomUser);
        uint256 proportionalStakingMockTokenBeforeStake = mockToken.balanceOf(address(proportionalStaking));

        mockToken.approve(address(proportionalStaking), stakeAmount_);
        proportionalStaking.stake(stakeAmount_);

        (uint256 randomUserStakedAfterStake, ) = proportionalStaking.userInfo(randomUser);
        uint256 totalStakedAfterStake = proportionalStaking.totalStaked();
        uint256 randomUserMockTokenAfterStake = mockToken.balanceOf(randomUser);
        uint256 proportionalStakingMockTokenAfterStake = mockToken.balanceOf(address(proportionalStaking));

        assertEq(randomUserStakedAfterStake - randomUserStakedBeforeStake, stakeAmount_);
        assertEq(totalStakedAfterStake - totalStakedBeforeStake, stakeAmount_);
        assertEq(randomUserMockTokenBeforeStake - randomUserMockTokenAfterStake, stakeAmount_);
        assertEq(proportionalStakingMockTokenAfterStake - proportionalStakingMockTokenBeforeStake, stakeAmount_);

        vm.stopPrank();
    }

    function test_RevertWhen_StakeZero() public {
        uint256 stakeAmount_ = 0 ether;
        vm.prank(randomUser);

        vm.expectRevert("Cannot stake 0.");
        proportionalStaking.stake(stakeAmount_);
    }

    function test_Unstake() public {
        uint256 stakeAmount_ = 100 ether;
        uint256 unstakeAmount_ = 40 ether;

        _stakeAsUser(randomUser, stakeAmount_);
        vm.startPrank(randomUser);  
        
        (uint256 randomUserStakedInMappingBeforeUnstake, ) = proportionalStaking.userInfo(randomUser);
        uint256 randomUserStakedBeforeUnstake = mockToken.balanceOf(randomUser);

        proportionalStaking.unstake(unstakeAmount_);

        (uint256 randomUserStakedInMappingAfterUnstake, ) = proportionalStaking.userInfo(randomUser);
        uint256 randomUserStakedAfterUnstake = mockToken.balanceOf(randomUser);

        assertEq(randomUserStakedInMappingBeforeUnstake - randomUserStakedInMappingAfterUnstake, unstakeAmount_);
        assertEq(randomUserStakedAfterUnstake - randomUserStakedBeforeUnstake, unstakeAmount_);
        vm.stopPrank();
    }

    function test_RevertWhen_UnstakeMoreThanStaked() public {
        uint256 stakeAmount_ = 100 ether;
        uint256 unstakeAmount_ = 240 ether;

        _stakeAsUser(randomUser, stakeAmount_);
        vm.startPrank(randomUser);

        vm.expectRevert("Not enough tokens.");
        proportionalStaking.unstake(unstakeAmount_);

        vm.stopPrank();
    }

    function test_SetRewardPerSecond() public {
        uint256 newRewardPerSecond = 80;
        vm.prank(owner);

        proportionalStaking.setRewardPerSecond(newRewardPerSecond);

        assertEq(proportionalStaking.rewardPerSecond(), newRewardPerSecond);
    }
    
    function test_RevertWhen_SetRewardPerSecondCallerNotOwner() public {
        uint256 newRewardPerSecond = 80;
        vm.prank(randomUser);

        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomUser)
        );
        proportionalStaking.setRewardPerSecond(newRewardPerSecond);
    }

    function test_ClaimRewards() public {
        uint256 stakeAmount_ = 200 ether;
        _stakeAsUser(randomUser, stakeAmount_);
        uint256 forwardTime_ = 1000000000000;

        vm.warp(block.timestamp + forwardTime_);

        uint256 randomUserRewardBalanceBeforeClaim = rewardToken.balanceOf(randomUser);

        vm.prank(randomUser);
        proportionalStaking.claimRewards();

        uint256 randomUserRewardBalanceAfterClaim = rewardToken.balanceOf(randomUser);
        uint256 rewardExpected_ = forwardTime_ * rewardPerSecond;

        assertEq(randomUserRewardBalanceAfterClaim - randomUserRewardBalanceBeforeClaim, rewardExpected_);
    }


    function test_RevertWhen_ClaimRewardsWithNothingPending() public {
        uint256 stakeAmount_ = 200 ether;
        _stakeAsUser(randomUser, stakeAmount_);

        vm.prank(randomUser);
        
        vm.expectRevert("Nothing to claim.");
        proportionalStaking.claimRewards();
    }

    function test_Stake_SettlesPreviousPendingFirst() public {
        uint256 stakeAmount_ = 100 ether;
        uint256 stakeAmount2_ = 200 ether;
        uint256 forwardTime_ = 30 days;
        _stakeAsUser(randomUser, stakeAmount_);

        vm.warp(block.timestamp + forwardTime_);
        vm.startPrank(randomUser);

        uint256 randomUserRewardBalanceBeforeStake = rewardToken.balanceOf(randomUser);
        
        mockToken.approve(address(proportionalStaking), stakeAmount2_);
        proportionalStaking.stake(stakeAmount2_);
        
        uint256 randomUserRewardBalanceAfterStake = rewardToken.balanceOf(randomUser);
        uint256 rewardExpected_ = forwardTime_ * rewardPerSecond;
        (uint256 randomUserInfoAmount_, ) = proportionalStaking.userInfo(randomUser);

        assertEq(randomUserRewardBalanceAfterStake - randomUserRewardBalanceBeforeStake, rewardExpected_);
        assertEq(randomUserInfoAmount_, stakeAmount_ + stakeAmount2_);
   
        vm.stopPrank();
    }

    function test_Unstake_PaysOutPendingRewardFirst() public {
        uint256 stakeAmount_ = 100 ether;
        uint256 unstakeAmount_ = 80 ether;
        uint256 forwardTime_ = 30 days;
        _stakeAsUser(randomUser, stakeAmount_);

        vm.warp(block.timestamp + forwardTime_);

        uint256 randomUserRewardBalanceBeforeUnstake = rewardToken.balanceOf(randomUser);

        vm.prank(randomUser);
        proportionalStaking.unstake(unstakeAmount_);

        uint256 randomUserRewardBalanceAfterUnstake = rewardToken.balanceOf(randomUser);
        uint256 expectedReward_ = forwardTime_ * rewardPerSecond;

        assertEq(randomUserRewardBalanceAfterUnstake - randomUserRewardBalanceBeforeUnstake, expectedReward_);
    }

    function test_TwoUsers_EqualStake_EqualReward() public {
        uint256 stakeAmount_ = 100 ether;
        uint256 forwardTime_ = 30 days;
        _stakeAsUser(randomUser, stakeAmount_);
        _stakeAsUser(secondRandomUser, stakeAmount_);

        vm.warp(block.timestamp + forwardTime_);
        
        vm.prank(randomUser);
        proportionalStaking.claimRewards();

        vm.prank(secondRandomUser);
        proportionalStaking.claimRewards();

        uint256 randomUserRewardAfterClaimReward = rewardToken.balanceOf(randomUser);
        uint256 secondRandomUserAfterClaimReward = rewardToken.balanceOf(secondRandomUser);
        assertEq(randomUserRewardAfterClaimReward, secondRandomUserAfterClaimReward);        
    }

    function test_SecondUserDoesNotStealEarlyRewards() public {
        uint256 stakeAmount_ = 100 ether;
        uint256 firstForwardTime_ = 30 days;
        uint256 secondForwardTime_ = 15 days;

        _stakeAsUser(randomUser, stakeAmount_);
        vm.warp(block.timestamp + firstForwardTime_);

        _stakeAsUser(secondRandomUser, stakeAmount_);
        vm.warp(block.timestamp + secondForwardTime_);

        vm.prank(secondRandomUser);
        proportionalStaking.claimRewards();

        uint256 totalStakedDuringSecondForwardTime_ = stakeAmount_ + stakeAmount_;
        uint256 expectedRewardSecondRandomUser = (rewardPerSecond * secondForwardTime_ * stakeAmount_) / totalStakedDuringSecondForwardTime_;
        uint256 rewardSecondRandomUserAfterClaim = rewardToken.balanceOf(secondRandomUser);

        assertEq(expectedRewardSecondRandomUser, rewardSecondRandomUserAfterClaim);
    }

    function test_UnequalStakes_ProportionalReward() public {
        uint256 stakeAmount_ = 100 ether;
        uint256 forwardTime_ = 30 days;
        uint256 proportion = 3;

        _stakeAsUser(randomUser, stakeAmount_);
        _stakeAsUser(secondRandomUser, stakeAmount_ * proportion);
        
        vm.warp(block.timestamp + forwardTime_);

        vm.prank(randomUser);
        proportionalStaking.claimRewards();

        vm.prank(secondRandomUser);
        proportionalStaking.claimRewards();

        uint256 totalStaked_ = stakeAmount_ + (stakeAmount_ * proportion);
        uint256 rewardPool_ = rewardPerSecond * forwardTime_;

        uint256 expectedRewardRandomUser_ = (rewardPool_ * stakeAmount_) / totalStaked_;
        uint256 expectedRewardSecondRandomUser_ = (rewardPool_ * stakeAmount_ * proportion) / totalStaked_;

        uint256 rewardSecondRandomUserAfterClaim = rewardToken.balanceOf(secondRandomUser);
        uint256 rewardRandomUserAfterClaim = rewardToken.balanceOf(randomUser);

        assertEq(rewardRandomUserAfterClaim, expectedRewardRandomUser_);
        assertEq(rewardSecondRandomUserAfterClaim, expectedRewardSecondRandomUser_);
    }

    function test_RevertWhen_ClaimRewardsTwiceWithoutWaiting() public {
        uint256 stakeAmount_ = 100 ether;
        uint256 forwardTime_ = 30 days;

        _stakeAsUser(randomUser, stakeAmount_);

        vm.warp(block.timestamp + forwardTime_);

        vm.startPrank(randomUser);
        proportionalStaking.claimRewards();

        vm.expectRevert("Nothing to claim.");
        proportionalStaking.claimRewards();

        vm.stopPrank();
    }

    function test_RevertWhen_UnstakeTwiceWithoutRestaking() public {
        uint256 stakeAmount_ = 100 ether;
        uint256 unstakeAmount_ = 100 ether;

        _stakeAsUser(randomUser, stakeAmount_);

        vm.startPrank(randomUser);
        proportionalStaking.unstake(unstakeAmount_);

        vm.expectRevert("Not enough tokens.");
        proportionalStaking.unstake(unstakeAmount_);

        vm.stopPrank();
    }

    function test_FullCycle_StakeUnstakeStakeAgain() public {
        uint256 firstStakeAmount_ = 100 ether;
        uint256 secondStakeAmount_ = 100 ether;
        uint256 unstakeAmount_ = 100 ether;
        uint256 forwardTime_ = 30 days;

        _stakeAsUser(randomUser, firstStakeAmount_);

        vm.warp(block.timestamp + forwardTime_);

        vm.prank(randomUser);
        proportionalStaking.unstake(unstakeAmount_);

        (uint256 amountStakedBeforeSecondStakeRandomUser, ) = proportionalStaking.userInfo(randomUser);
        uint256 rewardRandomUserBeforeSecondStake = rewardToken.balanceOf(randomUser);

        _stakeAsUser(randomUser, secondStakeAmount_);

        (uint256 amountStakedAfterSecondStakeRandomUser, ) = proportionalStaking.userInfo(randomUser);
        uint256 rewardRandomUserAfterSecondStake = rewardToken.balanceOf(randomUser);

        assertEq(amountStakedAfterSecondStakeRandomUser - amountStakedBeforeSecondStakeRandomUser, secondStakeAmount_);
        assertEq(rewardRandomUserAfterSecondStake, rewardRandomUserBeforeSecondStake);
    }

    // Fuzz tests

    function testFuzz_Stake(uint256 amount_) public {
        amount_ = bound(amount_, 1, MOCK_TOKEN_FUNDING);

        vm.startPrank(randomUser);

        mockToken.approve(address(proportionalStaking), amount_);
        proportionalStaking.stake(amount_);

        vm.stopPrank();

        (uint256 amountStaked_, ) = proportionalStaking.userInfo(randomUser);
        assertEq(amount_, amountStaked_);
    }

    function testFuzz_Unstake(uint256 stakeAmount_, uint256 unstakeAmount_) public {
        stakeAmount_ = bound(stakeAmount_, 1, MOCK_TOKEN_FUNDING);
        unstakeAmount_ = bound(unstakeAmount_, 1, stakeAmount_);

        _stakeAsUser(randomUser, stakeAmount_);

        vm.prank(randomUser);
        proportionalStaking.unstake(unstakeAmount_);

        (uint256 remainingStake_, ) = proportionalStaking.userInfo(randomUser);
        assertEq(remainingStake_, stakeAmount_ - unstakeAmount_);
    }

    // internal functions

    function _stakeAsUser(address user_, uint256 amount_) internal {
        vm.startPrank(user_);

        mockToken.approve(address(proportionalStaking), amount_);
        proportionalStaking.stake(amount_);

        vm.stopPrank();
    }
}