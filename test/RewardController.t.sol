import "./BaseSetup.sol";

contract RewardControllerTest is Test, BaseSetup {
    uint256 emission;
    function setUp() public virtual override {
        BaseSetup.setUp();
        vm.prank(GOV);
        kza.setBribeMinter(address(minter));
        // nominated in 10 ** 18 / unit
        BaseSetup.setupVoter(50000, 50000);
        BaseSetup.singlePoolVote(alice, alice, USDC);
        // setup lender1
        MockScaledERC20 vdToken = MockScaledERC20(mp.getReserveData(USDC).variableDebtTokenAddress);
        uint256 amount = 100 * 10 ** 18;

        vdToken.mint(borrower1, amount);

        skip(DURATION + 1);
        emission = minter.emission();
        minter.update_period();
        minter.notifyReward(USDC);
        // KZA get transferred to rewardVault;
        assertEq(kza.balanceOf(address(rv)), emission);
        // skip the emission duration
        skip(DURATION);
        minter.update_period();
    }

    function testClaimCheckLock() public {
        address[] memory assets = new address[](1);
        assets[0] = mp.getReserveData(USDC).variableDebtTokenAddress;
        address to = borrower1;
        vm.prank(to);
        rc.claimAllRewards(assets, to);
        // assert alice has a locked ratio of reward
        uint256 lockRatio = ts.lockRatio();
        assertEq(xkza.balanceOf(borrower1) / 10 ** 18, lockRatio * emission / PRECISION / 10 ** 18);
        assertEq(kza.balanceOf(borrower1) / 10 ** 18, (PRECISION - lockRatio) * emission / PRECISION / 10 ** 18);
    }
}