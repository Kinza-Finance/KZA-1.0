import "./BaseSetup.sol";

contract LockTransferStrategyTest is Test, BaseSetup {
    
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    function testUpdateLockRatio() public {
        uint256 newLockRatio = 10000;
        vm.prank(GOV);
        ts.updateLockRatio(newLockRatio);
        assertEq(ts.lockRatio(), newLockRatio);
    }

    function testUpdateLockRatioExceed() public {
        uint256 newLockRatio = 10001;
        vm.prank(GOV);
        vm.expectRevert("new lock ratio above 100%");
        ts.updateLockRatio(newLockRatio);
    }

    function testUpdateLockRatioNonOwner() public {
        uint256 newLockRatio = 10000;
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        ts.updateLockRatio(newLockRatio);
    }

    function testPerformTransfer() public {
        uint256 amount = DEFAULT * 10 ** 18;
        // deal to rewardsVault
        deal(address(kza), address(rv), amount);
        // allow this transferStrategy from rv for this amount
        vm.prank(address(dist));
        rv.approveTransferStrat(amount);
        // call from rewardController
        vm.prank(address(rc));
        ts.performTransfer(address(alice), address(kza), amount);
        // the result is some tokens get locked into xKZA for alice
        uint256 lockRatio = ts.lockRatio();
        assertEq(xkza.balanceOf(alice), amount * lockRatio / PRECISION);
        assertEq(kza.balanceOf(alice), amount * (PRECISION - lockRatio) / PRECISION);

    }

    function testPerformTransferReVote() public {
        testVote();
        skip(1 days);
        uint256 amount = DEFAULT * 10 ** 18;
        // deal to rewardsVault
        deal(address(kza), address(rv), amount);
        // allow this transferStrategy from rv for this amount
        vm.prank(address(dist));
        rv.approveTransferStrat(amount);
        vm.prank(address(rc));
        ts.performTransfer(address(alice), address(kza), amount);
        // a convertTo in performTransfer automatically helps revote
        uint256 used = votelogic.balanceOf(alice);
        //assert
        assertEq(voter.lastVoted(alice), block.timestamp);
        assertEq(voter.usedWeights(alice), used);

    }

    function testVote() public {
        address user = alice;
        address underlying = USDC;
        BaseSetup.setupVoter(100, 100);
        vm.prank(user);
        address[] memory _poolVote = new address[](1);
        uint256[] memory _weight = new uint256[](1);
        _poolVote[0] = underlying;
        //weight is relative so can be any number for a single pool
        _weight[0] = 100;
        voter.vote(user, _poolVote, _weight);
        uint256 used = votelogic.balanceOf(user);
        //assert
        assertEq(voter.lastVoted(user), block.timestamp);
        assertEq(voter.usedWeights(user), used);
        assertEq(voter.poolVote(user, 0), underlying);

        
    }

}