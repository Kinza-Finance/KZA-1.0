// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC20/ERC20.sol";

contract MockScaledERC20 is ERC20("MOCKERC20", "MEC") {
    function scaledTotalSupply() public view returns(uint256) {
        return totalSupply();
    }

    function getScaledUserBalanceAndSupply(address user) public view returns(uint256, uint256) {
        return (balanceOf(user), totalSupply());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}