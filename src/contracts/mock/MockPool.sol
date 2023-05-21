import "../../libraries/DataTypes.sol";

contract MockPool {
    // struct is too big to be exposed in public
    mapping(address => DataTypes.ReserveData) internal r;
    address[] public reserves;

    function getReserveData(address asset) public view returns(DataTypes.ReserveData memory) {
        return r[asset];
    }

    function getReservesList() public view returns(address[] memory) {
        return reserves;
    }

    function mintToTreasury(address[] calldata _assets) external {
    }

    // convenience function to manipulate data in the MockPool
    function pushReserve(address reserve) external {
        reserves.push(reserve);
    }

    // convenience function to manipulate data in the MockPool
    function changeATokenReserveList(address asset, address aToken) external {
        r[asset].aTokenAddress = aToken;
    }
    
    // convenience function to manipulate data in the MockPool
    function changeDTokenVariableReserveList(address asset, address vDToken) external {
        r[asset].variableDebtTokenAddress = vDToken;
    }

    function changeDTokenStableReserveList(address asset, address sDToken) external {
        r[asset].stableDebtTokenAddress = sDToken;
    }
}