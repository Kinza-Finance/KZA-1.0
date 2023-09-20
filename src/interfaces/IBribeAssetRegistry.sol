interface IBribeAssetRegistry {
    function isWhitelisted(address _underlying, address _asset) external returns(bool);
}