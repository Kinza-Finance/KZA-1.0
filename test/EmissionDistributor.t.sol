import "./BaseSetup.sol";

contract KZADistributorTest is Test, BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    function testSetVault() public {
        vm.prank(GOV);
        // it takes 0 too, but implies notifyReward would be paused
        address newVault;
        dist.setVault(newVault);
        assertEq(address(dist.vault()), newVault);
    }

    function testSetVaultNonOwner() public {
        address newVault;
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        dist.setVault(newVault);
    }

    function testSetEmissionManager() public {
        address newEmissionManager;
        vm.prank(GOV);
        dist.setEmissionManager(newEmissionManager);
        assertEq(address(dist.emisisonManager()), newEmissionManager);
    }

    function testSetEmissionManagerNonOwner() public {
        address newEmissionManager;
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        dist.setEmissionManager(newEmissionManager);
    }

    function testNotifyRewardNonMinter() public {
        address market;
        uint256 amount;
        vm.prank(alice);
        vm.expectRevert("onlyMinter");
        dist.notifyReward(market, amount);
    }

    function testNotifyRewardAllDToken() public {
        notifyReward();
    }

    function testNotifyRewardAllAToken() public {
        vm.prank(GOV);
        dist.updateKTokenRatio(1000);
        notifyReward();
    }

    function testNotifyRewardvDandAToken() public {
        vm.prank(GOV);
        dist.updateKTokenRatio(PRECISION/2);
        notifyReward();
    }

    function testNotifyRewardsDandAToken() public {
        vm.prank(GOV);
        dist.updateKTokenRatio(PRECISION/2);
        vm.prank(GOV);
        dist.updateStableDebtTokenRatio(PRECISION);
        notifyReward();
    }

    function testNotifyRewardAllDandAToken() public {
        vm.prank(GOV);
        dist.updateKTokenRatio(PRECISION/2);
        vm.prank(GOV);
        dist.updateStableDebtTokenRatio(PRECISION/2);
        notifyReward();
    }

    // notifyReward is triggered from minter notifyReward/notifyRewards
    function notifyReward() public {
        vm.prank(GOV);
        kza.setBribeMinter(address(minter));
        // nominated in 10 ** 18 / unit

        BaseSetup.setupVoter(50, 50);

        BaseSetup.singlePoolVote(alice, alice, USDC);

        skip(DURATION + 1);

        uint256 emission = minter.emission();
        minter.update_period();
        minter.notifyRewards();
        assertEq(kza.balanceOf(address(rv)), emission);
    }
    
}