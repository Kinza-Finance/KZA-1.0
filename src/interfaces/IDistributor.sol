pragma solidity ^0.8.17;

interface IDistributor {
    function notifyReward(address market, uint256 amount) external;
}