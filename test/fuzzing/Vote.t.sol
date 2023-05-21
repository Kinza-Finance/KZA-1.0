import { FuzzBase } from "./FuzzBase.sol";

contract VoteFuzzTests is FuzzBase {

    function testFuzz_singleVote(
         address user,
         uint256 weight,
         uint256 xKZABalance
    ) external {
        if (user == address(0)) {
            user = address(1);
        }
        // max to be supply of KZA
        xKZABalance = bound(xKZABalance, 1, 100_000_000 * 1e18);
        weight = bound(weight, 1, xKZABalance);
        deal(address(xkza), user, xKZABalance);
        address[] memory _poolVote = new address[](1);
        uint256[] memory _weight = new uint256[](1);
        address underlying = USDC;
        _poolVote[0] = underlying;
        //weight is relative so can be any number for a single pool
        _weight[0] = weight;
        vm.prank(user);
        voter.vote(user, _poolVote, _weight);

        uint256 used = votelogic.balanceOf(user);
        //assert
        assertEq(voter.lastVoted(user), block.timestamp);
        assertEq(voter.usedWeights(user), used);
    }
    function testFuzz_UpdateVote(
        address user,
        uint256 weight1,
        uint256 weight2,
        uint256 updatedWeight1,
        uint256 updatedWeight2,
        uint256 xKZABalance
    ) external {
        if (user == address(0)) {
            user = address(1);
        }
        assertEq(voter.totalWeight(), 0);
        // if there are two pools to vote, minBalance is 2 
        xKZABalance = bound(xKZABalance, 2, 100_000_000 * 1e18);
        // sum of weight should not be bigger than balance or each weight might be divfloor to 0
        weight1 = bound(weight1, 1, xKZABalance / 2);
        weight2 = bound(weight2, 1, xKZABalance / 2);
        updatedWeight1 = bound(updatedWeight1, 1, xKZABalance / 2);
        updatedWeight2 = bound(updatedWeight2, 1, xKZABalance / 2);
        deal(address(xkza), user, xKZABalance);

        address[] memory _poolVote = new address[](2);
        uint256[] memory _weight = new uint256[](2);
        _poolVote[0] = USDT;
        _poolVote[1] = USDC;
        //weight is relative so can be any number for a single pool
        _weight[0] = weight1;
        _weight[1] = weight2;
        vm.prank(user);
        voter.vote(user, _poolVote, _weight);
        skip(1);
        _weight[0] = updatedWeight1;
        _weight[1] = updatedWeight2;
        uint256 totalWeight = updatedWeight1 + updatedWeight2;
        vm.prank(user);
        voter.vote(user, _poolVote, _weight);
        uint256 used = votelogic.balanceOf(user);
        // since there  is only a voter, we check the total of each pool
        assertEq(voter.totalWeight(), used);
        assertEq(voter.weights(USDT), used * updatedWeight1 / totalWeight);
        assertEq(voter.weights(USDC), used * updatedWeight2 / totalWeight);
        assertEq(voter.votes(user,USDT), used * updatedWeight1 / totalWeight);
        assertEq(voter.votes(user,USDC), used * updatedWeight2 / totalWeight);

    }

    function testFuzz_TwoPoolVote(
         address user,
         uint256 weight1,
         uint256 weight2,
         uint256 xKZABalance
    ) external {
        if (user == address(0)) {
            user = address(1);
        }

        // if there are two pools to vote, minBalance is 2 
        xKZABalance = bound(xKZABalance, 2, 100_000_000 * 1e18);
        // sum of weight should not be bigger than balance or it is guaranteed to be divfloor
        weight1 = bound(weight1, 1, xKZABalance / 2);
        weight2 = bound(weight2, 1, xKZABalance / 2);
        deal(address(xkza), user, xKZABalance);
        address[] memory _poolVote = new address[](2);
        uint256[] memory _weight = new uint256[](2);
        _poolVote[0] = USDT;
        _poolVote[1] = USDC;
        //weight is relative so can be any number for a single pool
        _weight[0] = weight1;
        _weight[1] = weight2;
        uint256 totalWeight = weight1 + weight2;
        vm.prank(user);
        voter.vote(user, _poolVote, _weight);

        uint256 used = votelogic.balanceOf(user);
        //assert
        assertEq(voter.lastVoted(user), block.timestamp);
        assertEq(voter.totalWeight(), used);
        assertEq(voter.usedWeights(user), used);
        assertEq(voter.weights(USDT), used * weight1 / totalWeight);
        assertEq(voter.weights(USDC), used * weight2 / totalWeight);
        assertEq(voter.votes(user,USDT), used * weight1 / totalWeight);
        assertEq(voter.votes(user,USDC), used * weight2 / totalWeight);
    }

    function testFuzz_DoubleVoteWithRedeem(
        address user,
         uint256 weight1,
         uint256 weight2,
         uint256 xKZABalance,
         uint256 redeemingBalance,
         uint256 duration
    ) external {
        if (user == address(0)) {
            user = address(1);
        }

        // if there are two pools to vote, minBalance is 2, considering there is redeem discount we put 4 
        xKZABalance = bound(xKZABalance, 4, 100_000_000 * 1e18);

        deal(address(xkza), user, xKZABalance);

        uint256 minDuration = xkza.minRedeemDuration();
        uint256 maxDuration = xkza.maxRedeemDuration();
        // redeeming 1 balance is equal to 1 * 50% = 0, which is not valid
        redeemingBalance = bound(redeemingBalance, 4, xKZABalance);
        duration = bound(duration, minDuration, maxDuration);
        vm.prank(user);
        xkza.redeem(redeemingBalance, duration);
        // sum of weight should not be bigger than balance or it is guaranteed to be divfloor
        uint256 used = votelogic.balanceOf(user);

        weight1 = bound(weight1, 1, used / 2);
        weight2 = bound(weight2, 1, used / 2);
        address[] memory _poolVote = new address[](2);
        uint256[] memory _weight = new uint256[](2);
        _poolVote[0] = USDT;
        _poolVote[1] = USDC;
        //weight is relative so can be any number for a single pool
        _weight[0] = weight1;
        _weight[1] = weight2;
        vm.prank(user);
        voter.vote(user, _poolVote, _weight);
        //assert
        assertEq(voter.lastVoted(user), block.timestamp);
        assertEq(voter.usedWeights(user), used);

    }
}