import "./BaseSetup.sol";

contract ReserveFeeDistributorTest is Test, BaseSetup {
    uint256 DEFAULT_BRIBE = DEFAULT * 10 ** 18;
    function setUp() public virtual override {
        BaseSetup.setUp();
        //add all atoken as bribe
        address[] memory assets = mp.getReservesList();
        for (uint256 i; i < assets.length; ++i) {
            address aToken = mp.getReserveData(assets[i]).aTokenAddress;
            vm.prank(GOV);
            registry.addAsset(assets[i], address(aToken));
            // mint some aToken to ReserveFeeDsitributor
            MockERC20(aToken).mint(address(rdist), DEFAULT_BRIBE);
        }
    }

    function testUpdateBribeRatioNonOwner() public {
        uint256 _newBribeRatio = 10000;
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        rdist.updateBribeRatio(_newBribeRatio);
    }

    function testUpdateBribeRatio() public {
        uint256 _newBribeRatio = 10000;
        vm.prank(GOV);
        rdist.updateBribeRatio(_newBribeRatio);
        assertEq(rdist.bribeRatio(), _newBribeRatio);
    }

    function testPullFromTreasury() public {
        address[] memory assets = mp.getReservesList();
        // does not implement in IMockPool so it is an empty call
        rdist.pullFromTreasury(assets);
    }

    function testPullFromTreasurySplit() public {
        address[] memory assets = mp.getReservesList();
        rdist.pullFromTreasuryAndSplit(assets);
        assetsCheck(assets);
    }

    function testSplits() public {
        address[] memory assets = mp.getReservesList();
        rdist.splits(assets);
        assetsCheck(assets);
    }

    function assetsCheck(address[] memory assets) public {
        uint256 bribeRatio = rdist.bribeRatio();
        for (uint256 i; i < assets.length; ++i) {
            address aToken = mp.getReserveData(assets[i]).aTokenAddress;
            address bribe = voter.bribes(assets[i]);
            assertEq(MockERC20(aToken).balanceOf(treasury), bribeRatio * DEFAULT_BRIBE / PRECISION);
            assertEq(MockERC20(aToken).balanceOf(bribe), (PRECISION - bribeRatio) * DEFAULT_BRIBE / PRECISION);
        }   
    }
}