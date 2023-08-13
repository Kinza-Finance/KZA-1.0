pragma solidity ^0.8.17;

interface IBribeAssetRegistry {
    function isWhitelisted(address _asset) external returns(bool);
}