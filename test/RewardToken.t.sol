// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;


import "forge-std/Test.sol";
import "../src/RewardToken.sol";

contract RewardTokenTest is Test {
    
    RewardToken public rewardToken;
    address owner;
    uint256 constant INITIAL_SUPPLY = 1000;

    function setUp() public {
        owner = makeAddr("owner");
        vm.prank(owner);
        rewardToken = new RewardToken(INITIAL_SUPPLY);
    }

    function test_InitialSupplyMintsCorrectly() public view {
        assertEq(rewardToken.balanceOf(owner), INITIAL_SUPPLY);
    }

    function test_NameAndSymbol() public view {
        assertEq(rewardToken.name(), "RewardToken");
        assertEq(rewardToken.symbol(), "RWD");
    }

    function test_TotalSupplyMatchesMint() public view {
        assertEq(rewardToken.totalSupply(), INITIAL_SUPPLY);
    }

    function test_TransferReducesSenderBalance() public {
        address randomUser_ = makeAddr("randomUser");
        uint256 amount_ = 100;
        uint256 amountOwnerBeforeTransfer_ = rewardToken.balanceOf(owner);

        vm.prank(owner);
        rewardToken.transfer(randomUser_, amount_);

        assertEq(rewardToken.balanceOf(owner), amountOwnerBeforeTransfer_ - amount_);
        assertEq(rewardToken.balanceOf(randomUser_), amount_);
    }

}