import { FuzzBase } from "./FuzzBase.sol";

contract ConvertFuzzTests is FuzzBase {
    uint256 internal KZA_MAX_SUPPLY = 100_000_000 * 10 ** 18;
    function testFuzz_convert(
         address user,
         uint256 xkzaBalance,
         uint256 kzaBalance
    ) external {
        if (user == address(0)) {
            user = address(1);
        }
        kzaBalance = bound(kzaBalance, 1, KZA_MAX_SUPPLY); 
        xkzaBalance = bound(xkzaBalance, 0, KZA_MAX_SUPPLY - kzaBalance);
        deal(address(kza), user, kzaBalance);
        deal(address(xkza), user, xkzaBalance);
        vm.prank(user);
        kza.approve(address(xkza), kzaBalance);
        vm.prank(user);
        xkza.convert(kzaBalance);
        assertEq(xkza.balanceOf(user), xkzaBalance + kzaBalance);

    }
}