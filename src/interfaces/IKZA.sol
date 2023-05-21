import "@openzeppelin/token/ERC20/IERC20.sol";

interface IKZA is IERC20 {
  function KZA() external view returns(address);
  function burn(uint256 amount) external;
  function mint(address to, uint256 amount) external;
  function increaseAllowance(address spender, uint256 amount) external;
  function balanceOf(address _user) view external returns(uint256);
  function getUserRedeemsLength(address _user) view external returns(uint256);
  function getUserRedeem(address _user, uint256 _index) view external returns (uint256 amount, uint256 xAmount, uint256 endTime);
  function convertTo(uint256 amount, address to) external;
}