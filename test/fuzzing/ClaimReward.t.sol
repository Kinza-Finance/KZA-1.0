import { FuzzBase } from "./FuzzBase.sol";

contract ClaimRewardFuzzTests is FuzzBase {
    uint256 DEFAULT_BRIBE = DEFAULT * 10 ** 18;
    function setUp() public virtual override {
        super.setUp();
        vm.prank(GOV);
        registry.addAsset(address(bribeTokenA));
        assertEq(registry.isWhitelisted(address(bribeTokenA)), true);
        sendBribe();
    }
    function sendBribe() public {
        bribeTokenA.mint(alice, DEFAULT_BRIBE);
        vm.prank(alice);
        bribeTokenA.approve(address(eb), DEFAULT_BRIBE);
        vm.prank(alice);
        eb.notifyRewardAmount(address(bribeTokenA), DEFAULT_BRIBE);
        uint256 adjT = eb.getEpochStart(block.timestamp);
        uint256 epochRewards = eb.tokenRewardsPerEpoch(address(bribeTokenA), adjT);
        assertEq(epochRewards, DEFAULT_BRIBE);
    }
    // verify reward can be claimed across epoch, if the user does not update vote
    function testFuzz_ClaimRewardCacheVote(
        address user1,
        address user2,
        uint256 weight1,
        uint256 weight2,
        uint256 xKZABalance1,
        uint256 xKZABalance2
    ) external {
        if (user1 == address(0)) {
            user1 = address(1);
        }
        if (user2 == address(0)) {
            user2 = address(2);
        }
        // make sure these are two different addresses
        if (user2 == user1) {
            user2 = address(uint160(user1) ^ uint160(1));
        }
        // max to be supply of KZA
        xKZABalance1 = bound(xKZABalance1, 1, 100_000_000 * 1e18);
        xKZABalance2 = bound(xKZABalance2, 1, 100_000_000 * 1e18);
        // setting weight beyond actual xKZABalance would get the division during voting to be floored
        weight1 = bound(weight1, 1, xKZABalance1);
        weight2 = bound(weight2, 1, xKZABalance2);
        deal(address(xkza), user1, xKZABalance1);
        deal(address(xkza), user2, xKZABalance2);
        {
            address[] memory _poolVote = new address[](1);
            uint256[] memory _weight = new uint256[](1);
            address underlying = USDC;
            _poolVote[0] = underlying;
            //weight is relative so can be any number for a single pool
            _weight[0] = weight1;
            vm.prank(user1);
            voter.vote(user1, _poolVote, _weight);
            _weight[0] = weight2;
            vm.prank(user2);
            voter.vote(user2, _poolVote, _weight);
        }
        // claim reward after epoch
        skip(7 days);
        address[] memory _bribes = new address[](1);
        address[][] memory _tokens = new address[][](1);
        address[] memory token = new address[](1);
        _bribes[0] = address(eb);
        token[0] = address(bribeTokenA);
        _tokens[0] = token;
        address _to = address(user1);
        vm.prank(user1);
        voter.claimBribes(_bribes, _tokens, _to);
        
        // after 1 epoch passes and reward is claimed, briber send bribe in new epoch
        // last vote is not updated
        sendBribe();
        skip(7 days);
        vm.prank(user1);
        voter.claimBribes(_bribes, _tokens, _to);
        uint256 totalweight = xKZABalance1 + xKZABalance2;
        // user1 should have 2 portion of bribeTokenA now
        assertEq(bribeTokenA.balanceOf(user1), 2 * (DEFAULT_BRIBE * xKZABalance1 / totalweight));
    }
    function testFuzz_ClaimReward(
        address user1,
        address user2,
        uint256 weight1,
        uint256 weight2,
        uint256 xKZABalance1,
        uint256 xKZABalance2
    ) external {
        if (user1 == address(0)) {
            user1 = address(1);
        }
        if (user2 == address(0)) {
            user2 = address(2);
        }
        // make sure these are two different addresses
        if (user2 == user1) {
            user2 = address(uint160(user1) ^ uint160(1));
        }
        // max to be supply of KZA
        xKZABalance1 = bound(xKZABalance1, 1, 100_000_000 * 1e18);
        xKZABalance2 = bound(xKZABalance2, 1, 100_000_000 * 1e18);
        // setting weight beyond actual xKZABalance would get the division during voting to be floored
        weight1 = bound(weight1, 1, xKZABalance1);
        weight2 = bound(weight2, 1, xKZABalance2);
        deal(address(xkza), user1, xKZABalance1);
        deal(address(xkza), user2, xKZABalance2);
        {
            address[] memory _poolVote = new address[](1);
            uint256[] memory _weight = new uint256[](1);
            address underlying = USDC;
            _poolVote[0] = underlying;
            //weight is relative so can be any number for a single pool
            _weight[0] = weight1;
            vm.prank(user1);
            voter.vote(user1, _poolVote, _weight);
            _weight[0] = weight2;
            vm.prank(user2);
            voter.vote(user2, _poolVote, _weight);
        }
        // claim reward after epoch
        skip(7 days);
        address[] memory _bribes = new address[](1);
        address[][] memory _tokens = new address[][](1);
        address[] memory token = new address[](1);
        _bribes[0] = address(eb);
        token[0] = address(bribeTokenA);
        _tokens[0] = token;
        address _to = address(user1);
        vm.prank(user1);
        voter.claimBribes(_bribes, _tokens, _to);
        // noted rewards are splited based on voting power
        uint256 totalweight = xKZABalance1 + xKZABalance2;
        assertEq(bribeTokenA.balanceOf(user1), DEFAULT_BRIBE * xKZABalance1 / totalweight);

        vm.prank(user2);
        _to = address(user2);
        voter.claimBribes(_bribes, _tokens, _to);
        assertEq(bribeTokenA.balanceOf(user2), DEFAULT_BRIBE * xKZABalance2 / totalweight);

    }
}