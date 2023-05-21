// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20("MOCKERC20", "MEC") {
    function mint(address user, uint256 amount) external {
        _mint(user, amount);
    }
}