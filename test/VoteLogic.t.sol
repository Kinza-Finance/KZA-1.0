import "./BaseSetup.sol";

contract VoteLogicTest is Test, BaseSetup {

    
    function setUp() public virtual override {
        BaseSetup.setUp();

        ///give some money to alice
        BaseSetup.facuet(alice, DEFAULT);
    }

    function testUpdateDiscount() public {
        updateDiscount();
    }

    function testUpdateDiscountBiggerThan100() public {
        uint256 newDiscount = PRECISION + 1;
        itRevert("discount out of bound");
        vm.prank(GOV);
        votelogic.updateCountAs(newDiscount);
    }

    function testUpdateDiscountNonOwner() public {
        uint256 newDiscount = 400;
        itRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        votelogic.updateCountAs(newDiscount);
    }

    
    function testBalanceOfZero() public {
        assertEq(votelogic.balanceOf(alice), 0);
    }

    function testBalanceOfNonZero() public {
        uint256 balance = kza.balanceOf(alice);
        convert(alice, balance);
        assertEq(votelogic.balanceOf(alice), balance);
    }

    function testBalanceOfWithMaxRedeeming() public {
        uint256 balance = kza.balanceOf(alice);
        uint256 duration = xkza.maxRedeemDuration();
        uint256 countAs = votelogic.countAs();
        convert(alice, balance);
        redeem(alice, balance, duration);
        assertEq(votelogic.balanceOf(alice), balance * countAs / PRECISION);
    }

    function testBalanceOfWithMinRedeeming() public {
        uint256 balance = kza.balanceOf(alice);
        uint256 duration = xkza.minRedeemDuration();
        uint256 countAs = votelogic.countAs();
        convert(alice, balance);
        redeem(alice, balance, duration);
        assertEq(votelogic.balanceOf(alice), balance * countAs / PRECISION);
    }

    function testBalanceOfWithRedeemingDone() public {
        uint256 balance = kza.balanceOf(alice);
        uint256 duration = xkza.maxRedeemDuration();
        uint256 countAs = votelogic.countAs();
        convert(alice, balance);
        redeem(alice, balance, duration);
        skip(duration + 1);
        assertEq(votelogic.balanceOf(alice), balance * countAs / PRECISION);

    }

    function testBalanceOfWithReedemed() public {
        uint256 balance = kza.balanceOf(alice);
        uint256 duration = xkza.maxRedeemDuration();
        uint256 countAs = votelogic.countAs();
        convert(alice, balance);
        redeem(alice, balance, duration);
        skip(duration + 1);
        minter.update_period();
        vm.prank(alice);
        xkza.finalizeRedeem(0);
        assertEq(votelogic.balanceOf(alice), 0);
    }

    function testBalanceOfWithMaxRedeemingUpdate() public {
        uint256 balance = kza.balanceOf(alice);
        uint256 duration = xkza.maxRedeemDuration();
        uint256 countAs = votelogic.countAs();
        convert(alice, balance);
        redeem(alice, balance, duration);
        assertEq(votelogic.balanceOf(alice), balance * countAs / PRECISION);

        // update
        updateDiscount();
        uint256 newCountAs = votelogic.countAs();
        assertEq(votelogic.balanceOf(alice), balance * newCountAs / PRECISION);

    }

    function itRevert(string memory expRevertMessage
  ) public {
    vm.expectRevert(abi.encodePacked(expRevertMessage));
  }

    function convert(address user, uint256 amount) public override {
        vm.prank(user);
        return xkza.convert(amount);
    }

    function redeem(address user, uint256 xAmount, uint256 duration) public {
        vm.prank(user);
        xkza.redeem(xAmount, duration);
    }

    function updateDiscount() public {
        uint256 newDiscount = 400;
        vm.prank(GOV);
        votelogic.updateCountAs(newDiscount);
        assertEq(votelogic.countAs(), newDiscount);
    }
}