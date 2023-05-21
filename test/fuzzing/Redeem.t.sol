import { FuzzBase } from "./FuzzBase.sol";

contract RedeemFuzzTests is FuzzBase {
    uint256 internal KZA_MAX_SUPPLY = 100_000_000 * 10 ** 18;
    function testFuzz_redeem(
         address user,
         uint256 xkzaBalance,
         uint256 kzaBalance,
         uint256 redeemingBalance,
         uint256 duration
    ) external {
        if (user == address(0)) {
            user = address(1);
        }
        kzaBalance = bound(kzaBalance, 0, KZA_MAX_SUPPLY - 1); 
        xkzaBalance = bound(xkzaBalance, 1, KZA_MAX_SUPPLY - kzaBalance);
        deal(address(kza), user, kzaBalance);
        deal(address(xkza), user, xkzaBalance);

        uint256 minDuration = xkza.minRedeemDuration();
        uint256 maxDuration = xkza.maxRedeemDuration();
        // redeeming 1 balance is equal to 1 * 50% = 0, which is not valid
        redeemingBalance = bound(redeemingBalance, 1, xkzaBalance);
        duration = bound(duration, minDuration, maxDuration);
        vm.prank(user);
        xkza.redeem(redeemingBalance, duration);
        assertEq(xkza.balanceOf(user), xkzaBalance - redeemingBalance);
        // assert xamount
        (uint256 kzaAmount, uint256 xAmount, uint256 endPeriod) = xkza.getUserRedeem(user, 0);
        assertEq(xAmount, redeemingBalance);

    }
}