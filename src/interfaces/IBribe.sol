interface IBribe {
    function _deposit(uint256 _poolWeight, address _account) external;
    function _withdraw(uint256 _poolWeight, address _account) external;
    function getRewardForOwner(address[] memory _tokens, address _account, address _to) external;
    function getRewardForOwner(address _account, address _to) external;

    function notifyRewardAmount(address token, uint amount) external;
}