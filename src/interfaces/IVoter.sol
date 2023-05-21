interface IVoter {
    function weights(address market) external returns(uint256);
    function totalWeight() external returns(uint256);
    function reVote(address user) external;

    function bribes(address _asset) external view returns(address);
}