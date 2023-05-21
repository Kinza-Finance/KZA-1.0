import "./BaseSetup.sol";

contract AggregateBribeTest is Test, BaseSetup {
    uint256 DEFAULT_BRIBE = DEFAULT * 10 ** 18;
    function setUp() public virtual override {
        BaseSetup.setUp();
        //add bribeTokenA/B into registry
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

    function testNotifyRewardAmountNonWhitelist() public {
        vm.prank(alice);
        // send KZA token instead
        assertEq(registry.isWhitelisted(address(kza)), false);
        vm.expectRevert("bribe token must be whitelisted");
        eb.notifyRewardAmount(address(kza), DEFAULT_BRIBE);
    }

    function testNotifyRewardAmount() public {
        notifyRewardA();
    }

    function testNotifyRewardsAmount() public {
        notifyRewardA();
        notifyRewardB();
    }

    function testGetRewardsFromVoter() public {
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


    function testGetRewardsFromVoterDiff() public {
        notifyRewardA();
        notifyRewardB();
        uint256 aliceRatio = 90;
        uint256 bobRatio = 10;
        voteAndWait(aliceRatio, bobRatio);
        address[] memory _bribes = new address[](1);
        address[][] memory _tokens = new address[][](1);
        address[] memory token = new address[](2);
        _bribes[0] = address(eb);
        token[0] = address(bribeTokenA);
        token[1] = address(bribeTokenB);
        _tokens[0] = token;
        vm.prank(alice);
        voter.claimBribes(_bribes, _tokens, alice);
        assertEq(bribeTokenA.balanceOf(alice), DEFAULT_BRIBE * aliceRatio / 100);
        assertEq(bribeTokenB.balanceOf(alice), DEFAULT_BRIBE * aliceRatio / 100);
        vm.prank(bob);
        voter.claimBribes(_bribes, _tokens, bob);
        assertEq(bribeTokenA.balanceOf(bob), DEFAULT_BRIBE * bobRatio / 100);
        assertEq(bribeTokenB.balanceOf(bob), DEFAULT_BRIBE * bobRatio / 100);
    }

    function testGetReward() public {
        notifyRewardA();
        voteAndWait(50, 50);
        assertEq(eb.earned(address(bribeTokenA), alice), DEFAULT_BRIBE / 2);
        assertEq(eb.earned(address(bribeTokenA), bob), DEFAULT_BRIBE / 2);
    }


    function testBribeRewardAfterRevote() public {
        notifyRewardA();
        uint256 aliceRatio = 100;
        uint256 bobRatio = 100;
        setupVoter(aliceRatio, bobRatio);

        // alice and bob both 100 xtoken
        BaseSetup.singlePoolVote(alice, alice, USDT);
        // arbitrary time passes, but within the same epoch
        uint256 epoch = minter.epoch();
        uint256 elapse = 4 hours;
        skip(elapse);
        assertEq(epoch, minter.epoch());
        // alice change to voting for both pools
        BaseSetup.doublePoolVote(alice, alice, 50, 50);
        // bob vote for 1 pool only
        BaseSetup.singlePoolVote(bob, bob, USDC);

        // verify that alice now can only get 1/3 of bribe for pool USDT
        skip(DURATION);
        assertEq(eb.earned(address(bribeTokenA), alice), DEFAULT_BRIBE / 3);
    }

    function testGetRewardDirectly() public {
        notifyRewardA();
        notifyRewardB();
        voteAndWait(50, 50);
        uint256 earnedA = eb.earned(address(bribeTokenA), alice);
        uint256 earnedB = eb.earned(address(bribeTokenB), alice);
        vm.prank(alice);
        address[] memory tokens = new address[](2);
        tokens[0] = address(bribeTokenA);
        tokens[1] = address(bribeTokenB);
        eb.getReward(tokens);
        assertEq(bribeTokenA.balanceOf(alice), earnedA);
        assertEq(bribeTokenB.balanceOf(alice), earnedB);
    }

    function testGetRewardOwnerDirectly() public {
        notifyRewardA();
        notifyRewardB();
        voteAndWait(50, 50);
        uint256 earnedA = eb.earned(address(bribeTokenA), alice);
        uint256 earnedB = eb.earned(address(bribeTokenB), alice);
        vm.prank(alice);
        address[] memory tokens = new address[](2);
        tokens[0] = address(bribeTokenA);
        tokens[1] = address(bribeTokenB);
        eb.getRewardForOwner(tokens, alice, bob);
        assertEq(bribeTokenA.balanceOf(bob), earnedA);
        assertEq(bribeTokenA.balanceOf(bob), earnedB);
    }


    function testEpochStart() public {
        uint256 adjEpochTime = block.timestamp  - block.timestamp % 7 days;
        assertEq(eb.getEpochStart(block.timestamp), adjEpochTime);
    }

    function testPriorBalanceIndexNil() public {
        assertEq(eb.getPriorBalanceIndex(alice, block.timestamp), 0);
    }
    function testPriorBalanceIndex() public {
        uint256 aliceRatio = 100;
        uint256 bobRatio = 100;
        setupVoterRatio(aliceRatio, bobRatio);

        // alice and bob both 100 xtoken
        BaseSetup.singlePoolVote(alice, alice, USDC);
        // alice should have balance of 100 now 
        skip(1);
        assertEq(eb.getPriorBalanceIndex(alice, block.timestamp), 0);
        // voting on a different block increase the balance index
        skip(1);
        BaseSetup.singlePoolVote(alice, alice, USDC);
        assertEq(eb.getPriorBalanceIndex(alice, block.timestamp), 1);
    }

    function testPriorBalanceIndexDeep() public {
        uint256 aliceRatio = 100;
        uint256 bobRatio = 100;
        setupVoterRatio(aliceRatio, bobRatio);
        uint256 loop = 100;
        for (uint256 i; i < loop; ++i) {
            skip(1);
            BaseSetup.singlePoolVote(alice, alice, USDC);
            assertEq(eb.getPriorBalanceIndex(alice, block.timestamp), i);
        }
    }

    function testPriorSupplyIndexNil() public {
        assertEq(eb.getPriorSupplyIndex(block.timestamp), 0);
    }

    function testPriorSupplyIndex() public {
        uint256 aliceRatio = 100;
        uint256 bobRatio = 100;
        setupVoterRatio(aliceRatio, bobRatio);

        // alice and bob both 100 xtoken
        BaseSetup.singlePoolVote(alice, alice, USDC);
        // alice should have balance of 100 now 
        skip(1);
        assertEq(eb.getPriorSupplyIndex(block.timestamp), 0);
        skip(1);
        BaseSetup.singlePoolVote(alice, alice, USDC);
        // voting on a different block increase the totalSupply index
        assertEq(eb.getPriorSupplyIndex(block.timestamp), 1);
    }

    function testPriorSupplyIndexDeep() public {
        uint256 aliceRatio = 100;
        uint256 bobRatio = 100;
        setupVoterRatio(aliceRatio, bobRatio);
        uint256 loop = 100;
        for (uint256 i; i < loop; ++i) {
            skip(1);
            BaseSetup.singlePoolVote(alice, alice, USDC);
            assertEq(eb.getPriorSupplyIndex(block.timestamp), i);
        }
    }

    function testLastTimeRewardApplicable() public {
        notifyRewardA();
        assertEq(eb.lastTimeRewardApplicable(address(bribeTokenA)), block.timestamp);
    }

    function testLeft() public {
        notifyRewardA();
        assertEq(eb.left(address(bribeTokenA)), DEFAULT_BRIBE);
    }

    function testDepositNonVoter() public {
        uint256 aliceBalance = xkza.balanceOf(alice);
        vm.expectRevert("not voter");
        vm.prank(alice);
        eb._deposit(aliceBalance, alice);
    }

    function testWithdrawNonVoter() public {
        uint256 aliceBalance = xkza.balanceOf(alice);
        vm.expectRevert("not voter");
        vm.prank(alice);
        eb._deposit(aliceBalance, alice);
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

    
}
//