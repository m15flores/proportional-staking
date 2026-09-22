// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RewardToken is ERC20 {
    constructor(uint256 initialSupply_) ERC20("RewardToken", "RWD") {
        _mint(msg.sender, initialSupply_);
    }
}