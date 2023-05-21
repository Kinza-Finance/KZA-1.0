import "./BaseSetup.sol";

contract KZATest is Test, BaseSetup {
    uint256 amount = 100000 * 1e18;
    function setUp() public virtual override {
        BaseSetup.setUp();
        uint256 balance = kza.balanceOf(INIT_TOKENHOLDER);
        BaseSetup.facuet(address(ve), balance / 10 ** 18);
    }
    function testTotalWithdrawn() public {
        addVest();
        uint256 TimePass = ve.VESTING_PERIOD() + 1;
        skip(ve.CLIFF() + TimePass);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        uint256 amount = info.total;
        vm.prank(alice);
        uint256 maxClaim = 2 ** 256 - 1;
        ve.claim(maxClaim);
        assertEq(ve.totalWithdrawn(alice), amount);
    }

    function testViewGlobalLiquid() public {
        assertEq(ve.viewGlobalLiquid(), 0);
        addVest();
        assertEq(ve.viewGlobalLiquid(), 0);
        uint256 TimePass = 1;
        skip(ve.CLIFF() + TimePass);
        assertEq(ve.viewGlobalLiquid(), amount * TimePass / ve.VESTING_PERIOD());
        TimePass = ve.VESTING_PERIOD();
        skip(TimePass);
        assertEq(ve.viewGlobalLiquid(), amount);
    }


    // test add vesting
    function testAddReserveNonOwner() public {
        itRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        ve.addReserveVesting(alice, 1);
    } 
    // test add vesting
    function testAddNonOwner() public {
        itRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        ve.addVesting(alice, 1);
    }


    function testAddTooBigVesting() public {
        uint256 total = ve.TOTAL_AVAIALBLE();
        itRevert("not enough allocation");
        vm.prank(GOV);
        ve.addVesting(alice, total + 1);
    }



    function testAddToExistingVesting() public {
        addVest();
        itRevert("position exists");
        vm.prank(GOV);
        ve.addVesting(alice, 1);
    }
    function testAddVesting() public {
        addVest();
    }

    function testAddReserveVesting() public {
        addReserveVest();
    }

    function testUpdateVesting() public {
        addVest();
        skip(1);
        uint256 newVestingPeriod = 1000;
        uint256 newCliff = 1000;
        uint256 newAmount = 2;
        vm.prank(GOV);
        ve.updateVesting(alice, newAmount, newVestingPeriod, newCliff);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        assertEq(info.total, newAmount);
        assertEq(info.startTime, block.timestamp + newCliff);
        assertEq(info.vestingPeriod, newVestingPeriod);
    }

    function testUpdateReserveVesting() public {
        addReserveVest();
        skip(1);
        uint256 newVestingPeriod = 1000;
        uint256 newCliff = 1000;
        uint256 newAmount = 2;
        vm.prank(GOV);
        ve.updateVesting(alice, newAmount, newVestingPeriod, newCliff);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        assertEq(info.total, newAmount);
        assertEq(info.startTime, block.timestamp + newCliff);
        assertEq(info.vestingPeriod, newVestingPeriod);
    }

    function testUpdateVestingWithTooBig() public {
        addVest();
        skip(1);
        uint256 newVestingPeriod = 1000;
        uint256 newCliff = 1000;
        uint256 total = ve.TOTAL_AVAIALBLE();
        uint256 newAmount = 1 + total;
        vm.prank(GOV);
        itRevert("not enough allocation");
        ve.updateVesting(alice, newAmount, newVestingPeriod, newCliff);
    }
    // test remove vesting 
    function testRemoveValidVesting() public {
        addVest();
        vm.prank(GOV);
        ve.removeVesting(alice);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        assertEq(info.total, 0);
        assertEq(info.startTime, 0);
        assertEq(info.vestingPeriod, 0);
    }

    function testRemoveValidReserveVesting() public {
        addReserveVest();
        vm.prank(GOV);
        ve.removeVesting(alice);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        assertEq(info.total, 0);
        assertEq(info.startTime, 0);
        assertEq(info.vestingPeriod, 0);
    }
    // test update vesting
    function testRemoveNonExistentVesting() public {
        vm.prank(GOV);
        itRevert("non existent vesting position");
        ve.removeVesting(alice);
    }
    // test claim
    function testClaimNonExistent() public {
        itRevert("There is no active position");
        vm.prank(alice);
        uint256 maxClaim = 2 ** 256 - 1;
        ve.claim(maxClaim);
    }

    function testClaimInTheBeginning() public {
        addVest();
        itRevert("vesting starts in future");
        vm.prank(alice);
        uint256 maxClaim = 2 ** 256 - 1;
        ve.claim(maxClaim);
        

    }

    function testClaimPassTheCliff1Unit() public {
        addVest();
        uint256 TimePass = 1;
        skip(ve.CLIFF() + TimePass);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        vm.prank(alice);
        uint256 toClaim = 1;
        ve.claim(toClaim);
        assertEq(kza.balanceOf(alice), toClaim);
    }

    function testClaimPassTheCliff() public {
        addVest();
        uint256 TimePass = 1;
        skip(ve.CLIFF() + TimePass);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        uint256 amount = info.total;
        vm.prank(alice);
        uint256 maxClaim = 2 ** 256 - 1;
        ve.claim(maxClaim);
        assertEq(kza.balanceOf(alice), TimePass * amount / ve.VESTING_PERIOD());
    }

    function testClaim50Vesting() public {
        addVest();
        uint256 TimePass = ve.VESTING_PERIOD() / 2;
        skip(ve.CLIFF() + TimePass);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        uint256 amount = info.total;
        vm.prank(alice);
        uint256 maxClaim = 2 ** 256 - 1;
        ve.claim(maxClaim);
        assertEq(kza.balanceOf(alice), TimePass * amount / ve.VESTING_PERIOD());
    }

    function testClaimBeyondVestingPeriod() public {
        addVest();
        uint256 TimePass = ve.VESTING_PERIOD() + 1;
        skip(ve.CLIFF() + TimePass);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        uint256 amount = info.total;
        vm.prank(alice);
        uint256 maxClaim = 2 ** 256 - 1;
        ve.claim(maxClaim);
        assertEq(kza.balanceOf(alice), amount);
    }
    // test claimTo
    function testClaimToNonExistent() public {
        itRevert("There is no active position");
        vm.prank(alice);
        uint256 maxClaim = 2 ** 256 - 1;
        ve.claimTo(bob, maxClaim);
    }
    function testClaimToInTheBeginning() public {
        addVest();
        itRevert("vesting starts in future");
        vm.prank(alice);
        uint256 maxClaim = 2 ** 256 - 1;
        ve.claimTo(bob, maxClaim);
    }

    function testClaimToPassTheCliff1Unit() public {
        addVest();
        uint256 TimePass = 1;
        skip(ve.CLIFF() + TimePass);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        vm.prank(alice);
        uint256 toClaim = 1;
        ve.claimTo(bob, toClaim);
        assertEq(kza.balanceOf(bob), toClaim);
    }

    function testClaimToPassTheCliff() public {
        addVest();
        uint256 TimePass = 1;
        skip(ve.CLIFF() + TimePass);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        uint256 amount = info.total;
        vm.prank(alice);
        uint256 maxClaim = 2 ** 256 - 1;
        ve.claimTo(bob, maxClaim);
        assertEq(kza.balanceOf(bob), TimePass * amount / ve.VESTING_PERIOD());
    }

    function testClaimTo50Vesting() public {
        addVest();
        uint256 TimePass = ve.VESTING_PERIOD() / 2;
        skip(ve.CLIFF() + TimePass);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        uint256 amount = info.total;
        vm.prank(alice);
        uint256 maxClaim = 2 ** 256 - 1;
        ve.claimTo(bob, maxClaim);
        assertEq(kza.balanceOf(bob), TimePass * amount / ve.VESTING_PERIOD());
    }

    function testClaimToBeyondVestingPeriod() public {
        addVest();
        uint256 TimePass = ve.VESTING_PERIOD() / 2;
        skip(ve.CLIFF() + TimePass);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        uint256 amount = info.total;
        vm.prank(alice);
        uint256 maxClaim = 2 ** 256 - 1;
        ve.claimTo(bob, maxClaim);
        assertEq(kza.balanceOf(bob), amount / 2);
    }


    function addVest() public {
        vm.prank(GOV);
        ve.addVesting(alice, amount);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        assertEq(info.total, amount);
        assertEq(info.startTime, ve.CLIFF() + block.timestamp);
        assertEq(info.vestingPeriod, ve.VESTING_PERIOD());
    }

    function addReserveVest() public {
        vm.prank(GOV);
        ve.addReserveVesting(alice, amount);
        VestingEscrow.AccountInfo memory info = ve.getAccountInfo(alice);
        assertEq(info.total, amount);
        assertEq(info.startTime, ve.RESERVE_CLIFF() + block.timestamp);
        assertEq(info.vestingPeriod, ve.RESERVE_VESTING_PERIOD());
    }


    function itRevert(string memory expRevertMessage
  ) public {
    vm.expectRevert(abi.encodePacked(expRevertMessage));
  }
    
}