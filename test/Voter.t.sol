import "./BaseSetup.sol";

contract VoterTest is Test, BaseSetup {
    
    uint256 DEFAULT_BRIBE = DEFAULT * 10 ** 18;
    function setUp() public virtual override {
        BaseSetup.setUp();
        BaseSetup.setupVoter(100, 100);
        vm.prank(GOV);
        registry.addAsset(address(bribeTokenA));
        assertEq(registry.isWhitelisted(address(bribeTokenA)), true);
        vm.prank(GOV);
        registry.addAsset(address(bribeTokenB));
        assertEq(registry.isWhitelisted(address(bribeTokenB)), true);
        // so alice can send in bribe later
        bribeTokenA.mint(alice, DEFAULT_BRIBE);
        bribeTokenB.mint(alice, DEFAULT_BRIBE);
    }

    function testMarketLength() public {
        assertEq(voter.marketLength(), 2);
    }

    function testIsDelegateSelf() public {
        vm.prank(alice);
        assertEq(voter.isDelegatedOrOwner(alice, alice), true);
    }

    function testIsDelegateInvalid() public {
        assertEq(voter.isDelegatedOrOwner(alice, bob), false);
    }

    function testPushUnderlying() public {
        uint256 marketLength = voter.marketLength();
        vm.prank(GOV);
        voter.pushUnderlying(address(bribeTokenA));
        assertEq(voter.marketLength(), marketLength + 1);
    }
    

    function testUpdateVoteLogic() public {
        address _newVoteLogic = address(0);
        vm.prank(GOV);
        voter.updateVoteLogic(_newVoteLogic);
        assertEq(address(voter.voteLogic()), _newVoteLogic);
    }

    function testUpdateVoteLogicNonOwner() public {
        address _newVoteLogic = address(0);
        vm.expectRevert("Ownable: caller is not the owner");
        voter.updateVoteLogic(_newVoteLogic);
    }

    function testUpdateMinter() public {
        address _minter = address(1);
        vm.prank(GOV);
        voter.updateMinter(_minter);
        assertEq(address(voter.minter()), _minter);
    }

    function testUpdateMinterNonOwner() public {
        address _newMinter = address(1);
        vm.expectRevert("Ownable: caller is not the owner");
        voter.updateMinter(_newMinter);
    }

    function testVote() public {
        singlePoolVote(alice, alice, USDC);
    }

    // function testVoteSameEpoch() public {
    //     singlePoolVote(alice, alice, USDC);
    //     vm.expectRevert("holder already voted in this epoch");
    //     singlePoolVote(alice, alice, USDC);
    // }

    function testVoteSameEpoch() public {
        singlePoolVote(alice, alice, USDC);
        singlePoolVote(alice, alice, USDC);
    }

    function testUpdateVote() public {
        // make alice and bob both 100 xtoken
        BaseSetup.doublePoolVote(alice, alice, 99, 1);
        BaseSetup.doublePoolVote(alice, alice, 50, 50);
    }

    function testUpdateVoteReward() public {
        // alice and bob both 100 xtoken
        BaseSetup.singlePoolVote(alice, alice, USDT);
        // alice change to voting for both pools
        BaseSetup.doublePoolVote(alice, alice, 50, 50);
        // bob vote for 1 pool only
        BaseSetup.singlePoolVote(bob, bob, USDC);
        
    }

    function testVoteNextEpoch() public {
        singlePoolVote(alice, alice, USDC);
        skip(DURATION + 1);
        minter.update_period();
        singlePoolVote(alice, alice, USDC);
    }

    function testReVoteFromEOA() public {
        singlePoolVote(alice, alice, USDC);
        vm.prank(alice);
        vm.expectRevert("caller not xToken");
        voter.reVote(alice);
    }

    function testReVoteFromXTokenRedeem() public {
        singlePoolVote(alice, alice, USDC);
        uint256 balance = xkza.balanceOf(alice);
        uint256 duration = xkza.minRedeemDuration();
        vm.prank(alice);
        // redeem trigger revote
        xkza.redeem(balance, duration);
        // count
        uint256 countAs = votelogic.countAs();
        // usedWeight would be updated
        assertEq(countAs * balance / PRECISION, voter.usedWeights(alice));
    }
    //admin

    function testUpdateDelegate() public {
        vm.prank(alice);
        voter.updateDelegate(bob);
        assertEq(voter.isDelegatedOrOwner(bob, alice), true);
    }

    function testVoteFromDelegate() public {
        vm.prank(alice);
        voter.updateDelegate(bob);
        singlePoolVote(bob, alice, USDC);

    }

    function testRemoveDelegate() public {
        vm.prank(alice);
        voter.updateDelegate(bob);
        vm.prank(alice);
        voter.updateDelegate(address(0));  
        address[] memory _poolVote = new address[](1);
        uint256[] memory _weight = new uint256[](1);
        _poolVote[0] = USDC;
        //weight is relative so can be any number for a single pool
        _weight[0] = 100;
        itRevert("not owner or delegated");
        vm.prank(bob);
        voter.vote(alice, _poolVote, _weight);

    }

    function testClaimBribes() public {
        notifyRewardA();
        notifyRewardB();
        voteAndWait(50, 50);
        address[] memory _bribes = new address[](1);
        address[][] memory _tokens = new address[][](1);
        address[] memory token = new address[](2);
        _bribes[0] = address(eb);
        token[0] = address(bribeTokenA);
        token[1] = address(bribeTokenB);
        _tokens[0] = token;
        address _account = address(alice);
        address _to = address(alice);
        vm.prank(_account);
        voter.claimBribes(_bribes, _tokens, _to);
        assertEq(bribeTokenA.balanceOf(alice), DEFAULT_BRIBE / 2);
        assertEq(bribeTokenB.balanceOf(alice), DEFAULT_BRIBE / 2);
    }

    function notifyRewardA() public {
        vm.prank(alice);
        bribeTokenA.approve(address(eb), DEFAULT_BRIBE);
        vm.prank(alice);
        eb.notifyRewardAmount(address(bribeTokenA), DEFAULT_BRIBE);
        uint256 adjT = eb.getEpochStart(block.timestamp);
        uint256 epochRewards = eb.tokenRewardsPerEpoch(address(bribeTokenA), adjT);
        assertEq(epochRewards, DEFAULT_BRIBE);
    }

    function notifyRewardB() public {
        vm.prank(alice);
        bribeTokenB.approve(address(eb), DEFAULT_BRIBE);
        vm.prank(alice);
        eb.notifyRewardAmount(address(bribeTokenB), DEFAULT_BRIBE);
        uint256 adjT = eb.getEpochStart(block.timestamp);
        uint256 epochRewards = eb.tokenRewardsPerEpoch(address(bribeTokenB), adjT);
        assertEq(epochRewards, DEFAULT_BRIBE);
    }

    function setupVoterRatio(uint256 aliceBalance, uint256 bobBalance) public {
        BaseSetup.facuet(alice, aliceBalance);
        BaseSetup.facuet(bob, bobBalance);
        // set up alice bob as voter
        BaseSetup.convert(alice, aliceBalance);
        BaseSetup.convert(bob, bobBalance);
    }
    
    function voteAndWait(uint256 aliceBalance, uint256 bobBalance) public {
        // 2 voter vote
        setupVoterRatio(aliceBalance, bobBalance);
        BaseSetup.singlePoolVote(alice, alice, USDC);
        BaseSetup.singlePoolVote(bob, bob, USDC);
        skip(DURATION);
    }
    // simple vote
    function singlePoolVote(address delegate, address user, address underlying) override public {
        vm.prank(delegate);
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


    function convert(address user, uint256 amount) public override {
        vm.prank(user);
        return xkza.convert(amount);
    }

    function itRevert(string memory expRevertMessage
  ) public {
    vm.expectRevert(abi.encodePacked(expRevertMessage));
  }



}