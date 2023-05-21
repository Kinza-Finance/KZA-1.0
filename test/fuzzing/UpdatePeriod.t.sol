import { FuzzBase } from "./FuzzBase.sol";

contract UpdateEpochFuzzTests is FuzzBase {

    function setUp() public virtual override {
        super.setUp();
        vm.prank(GOV);
        kza.setBribeMinter(address(minter));
    }
    function testFuzz_updatePeriod(
        // block.timestamp is uint32
        uint256 timestamp
    ) external {
        uint256 kzaBalanceBefore = kza.balanceOf(address(minter));
        uint256 epoch = minter.epoch();
        uint256 emission = minter.emission();
        // so the new block.timestamp is within uint256
        timestamp = bound(timestamp, 0, type(uint256).max - block.timestamp);
        skip(timestamp);
        minter.update_period();
        if (epoch == minter.epoch()) {
            assertEq(kzaBalanceBefore, kza.balanceOf(address(minter)));
        } else {
            assertEq(kza.balanceOf(address(minter)) , kzaBalanceBefore + emission);
        }
        
    }
}