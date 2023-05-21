import "./BaseSetup.sol";

contract MinterTest is Test, BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
        vm.prank(GOV);
        kza.setBribeMinter(address(minter));
        // nominated in 10 ** 18 / unit

        BaseSetup.facuet(alice, DEFAULT);
        BaseSetup.convert(alice, DEFAULT);
        
    }

    function testGetReserves() public {
        address[] memory reserve = minter.getReserves();
        assertEq(reserve.length, 2);
    }
    function testUpdateDisbutorNonOwner() public {
        address _newDistributor = address(alice);
        itRevert("Ownable: caller is not the owner");
        minter.updateDistributor(_newDistributor);
    }
    function testUpdateDisbutor() public {
        vm.prank(GOV);
        address _newDistributor = address(alice);
        minter.updateDistributor(_newDistributor);
        assertEq(minter.distributor(), _newDistributor);
    }
    // test update epoch
    function testUpdateEpoch() public {
        skip(DURATION + 1);
        uint256 emission = minter.emission();
        minter.update_period();
        assertEq(kza.balanceOf(address(minter)), emission);
    }

    function testUpdateEpochWithinSameWeek() public {
        skip(DURATION + 1);
        minter.update_period();
        string memory expRevertMessage = "only trigger each new week";
        vm.expectRevert(abi.encodePacked(expRevertMessage));
        minter.update_period();
    }


    function testUpdateDecay() public {
        // 1%
        uint256 newDecay = 100;
        uint256 decay = minter.decay();
        vm.prank(GOV);
        minter.updateDecay(newDecay);
        assertEq(minter.decay(), newDecay);
    }

    function testUpdateTooBigDecay() public {
        uint256 PRECISION = 10000;
        // 1%
        uint256 newDecay = PRECISION + 1;
        itRevert("decay exceeds maximum");
        vm.prank(GOV);
        minter.updateDecay(newDecay);
        
    }

    function testUpdateDecayNonOwner() public {
        uint256 newDecay = 1;
        itRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        minter.updateDecay(newDecay);
    }

    function testUpdateVoter() public {
        address newVoter = address(alice);
        vm.prank(GOV);
        // probably should never put a newVoter as an EOA, which would break update_epoch and notifyReward
        minter.updateVoter(newVoter);
        assertEq(address(minter.voter()), address(alice));
    }

    function testUpdateVoterNonOwner() public {
        address newVoter = address(alice);
        itRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        minter.updateVoter(newVoter);
    }

    function testNotifyRewardPostVote() public {
        BaseSetup.setupVoter(50, 50);
        BaseSetup.singlePoolVote(alice, alice, USDC);
        skip(DURATION + 1);
        uint256 emission = minter.emission();
        minter.update_period();
        minter.notifyReward(USDC);
        // KZA get transferred to rewardVault;
        assertEq(kza.balanceOf(address(rv)), emission);

    }

    function testNotifyRewardsPostVote() public {
        BaseSetup.setupVoter(50, 50);
        BaseSetup.singlePoolVote(alice, alice, USDC);
        skip(DURATION + 1);
        uint256 emission = minter.emission();
        minter.update_period();
        minter.notifyRewards();
        // KZA get transferred to rewardVault;
        assertEq(kza.balanceOf(address(rv)), emission);

    }

    // test integration with voter
    function itRevert(string memory expRevertMessage
  ) public {
    vm.expectRevert(abi.encodePacked(expRevertMessage));
  }


    
}