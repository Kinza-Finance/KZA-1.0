

interface IXToken {
    function balanceOf(address _user) view external returns(uint256);
    function getUserRedeemsLength(address _user) view external returns(uint256);
    function getUserRedeem(address _user, uint256 _index) view external returns (uint256 amount, uint256 xAmount, uint256 endTime);

}