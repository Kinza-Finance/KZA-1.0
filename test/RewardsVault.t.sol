import "./BaseSetup.sol";

contract RewardsVaultTest is Test, BaseSetup {
    
    function setUp() public virtual override {
        BaseSetup.setUp();

    }

    function testUpdateTransferStrat() public {
        address _newTransferStrategy = address(alice);
        vm.prank(GOV);
        rv.updateTransferStrat(_newTransferStrategy);
        assertEq(address(alice), rv.transferStrategy());
    }


    function testApproveTransferStrat() public {
        uint256 amount = DEFAULT * 10 ** 18;
        vm.prank(address(dist));
        rv.approveTransferStrat(amount);
        assertEq(kza.allowance(address(rv), rv.transferStrategy()), amount);
    }

    function testResecureFund() public {
        uint256 amount = DEFAULT * 10 ** 18;
        uint256 before = kza.balanceOf(GOV);
        deal(address(kza), address(rv), amount);
        vm.prank(GOV);
        rv.resecureFund(amount);
        assertEq(kza.balanceOf(GOV), before + amount);

    }

    function testSunsetTransferStrat() public {
        address tsAddress = rv.transferStrategy();
        vm.prank(GOV);
        rv.sunsetTransferStrat(tsAddress);
        assertEq(kza.allowance(address(rv), rv.transferStrategy()), 0);
    }

}
