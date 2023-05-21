import "./BaseSetup.sol";

contract XKZATest is Test, BaseSetup {
    
    function setUp() public virtual override {
        BaseSetup.setUp();
        BaseSetup.facuet(alice, DEFAULT);
        BaseSetup.facuet(bob, DEFAULT);
    }

    // test updateVoter
    function testUpdateVoter() public {
        address _newVoter = address(alice);
        vm.prank(GOV);
        xkza.updateVoter(_newVoter);
        assertEq(address(xkza.voter()), _newVoter);
    }

    function testUpdateVoterNonOwner() public {
        address _newVoter = address(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        xkza.updateVoter(_newVoter);
    }

    function testUpdateRedeemSettings() public {
        (uint256 _minRedeemRatio, uint256 _maxRedeemRatio, uint256 _minRedeemDuration, uint256 _maxRedeemDuration) = getRedeemParameter();
        vm.prank(GOV);
        // maxRedeemRatio cannot exceed 100, which is 100 now
        xkza.updateRedeemSettings(_minRedeemRatio + 1, _maxRedeemRatio, _minRedeemDuration + 1, _maxRedeemDuration+1);
        (uint256 _newMinRedeemRatio, uint256 _newMaxRedeemRatio, uint256 _newMinRedeemDuration, uint256 _newMaxRedeemDuration) = getRedeemParameter();
        assertEq(_minRedeemRatio + 1, _newMinRedeemRatio);
        assertEq(_maxRedeemRatio, _newMaxRedeemRatio);
        assertEq(_minRedeemDuration + 1, _newMinRedeemDuration);
        assertEq(_maxRedeemDuration + 1, _newMaxRedeemDuration);
        
    }

    function testUpdateRedeemSettingsInvalid() public {
        (uint256 _minRedeemRatio, uint256 _maxRedeemRatio, uint256 _minRedeemDuration, uint256 _maxRedeemDuration) = getRedeemParameter();
        vm.prank(GOV);
        vm.expectRevert("updateRedeemSettings: wrong ratio values");
        xkza.updateRedeemSettings(_minRedeemRatio, _minRedeemRatio - 1, _minRedeemDuration, _maxRedeemDuration);
        vm.prank(GOV);
        vm.expectRevert("updateRedeemSettings: wrong duration values");
        xkza.updateRedeemSettings(_minRedeemRatio, _maxRedeemRatio, _maxRedeemDuration + 1, _maxRedeemDuration);
        vm.prank(GOV);
        vm.expectRevert("updateRedeemSettings: max redeem ratio exceeds");
        xkza.updateRedeemSettings(_minRedeemRatio, 101, _minRedeemDuration, _maxRedeemDuration);
    }

    function testUpdateRedeemSettingsNonOwner() public {
        (uint256 _minRedeemRatio, uint256 _maxRedeemRatio, uint256 _minRedeemDuration, uint256 _maxRedeemDuration) = getRedeemParameter();
        vm.expectRevert("Ownable: caller is not the owner");
        xkza.updateRedeemSettings(_minRedeemRatio, _maxRedeemRatio, _minRedeemDuration, _maxRedeemDuration);
    }


    // test convert
    function testConvertWhole() public {
        uint256 balance = kza.balanceOf(alice);
        convert(alice, balance);
        itConvertAmountMatch(alice, balance);
    }

    function testConvertOne() public {
        uint256 balance = kza.balanceOf(alice);
        convert(alice, 1);
        itConvertAmountMatch(alice, 1);
    }

     function testConvertNone() public {
        uint256 balance = kza.balanceOf(alice);
        string memory expRevertMessage = "convert: amount cannot be null";
        vm.expectRevert(abi.encodePacked(expRevertMessage));
        convert(alice, 0);     
    }

    
    function testConvertWholeTo() public {
        uint256 balance = kza.balanceOf(alice);
        string memory expRevertMessage = "convertTo: not allowed for EOA";
        vm.expectRevert(abi.encodePacked(expRevertMessage));
        convertTo(alice, bob, balance);
    }

    function testConvertTo() public {
        uint256 amount = 100 * 10 ** 18;
        deal(address(kza), address(ts), amount);
        convertTo(address(ts), alice, amount);
    }

    function testConvertVoteUpdate() public {
        address user = alice;
        address underlying = USDC;
        BaseSetup.setupVoter(100, 100);
        vm.prank(user);
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

        skip(1 days);
        uint256 moreKZA = 10 * 10 ** 18;
        deal(address(kza), alice, moreKZA);
        vm.prank(alice);
        xkza.convert(moreKZA);
        // a convert automatically helps revote
        used = votelogic.balanceOf(user);
        //assert
        assertEq(voter.lastVoted(user), block.timestamp);
        assertEq(voter.usedWeights(user), used);
    }


    function testCannotConvertMoreThanAvaialble() public {
        uint256 balance = kza.balanceOf(alice);
        string memory expRevertMessage = "ERC20: transfer amount exceeds balance";
        vm.expectRevert(abi.encodePacked(expRevertMessage));
        convert(alice, balance + 1);
    }

    //test transfer
    function testCannotTransfer() public {
        string memory expRevertMessage = "xToken does not allow transfer";
        vm.expectRevert(abi.encodePacked(expRevertMessage));
        vm.prank(alice);
        xkza.transfer(bob, 1);
    }

    // test redeem

    function testRedeemMinimumCooldown() public {
        uint256 duration = xkza.minRedeemDuration();
        uint256 balance = kza.balanceOf(alice);
        convert(alice, balance);
        redeem(alice, balance, duration);
        ifRedeemAmountMatch(alice, balance, duration);
    }

    function testRedeemMaximumCooldown() public {
        uint256 duration = xkza.maxRedeemDuration();
        uint256 balance = kza.balanceOf(alice);
        convert(alice, balance);
        redeem(alice, balance, duration);
        ifRedeemAmountMatch(alice, balance, duration);
    }

    function testRedeem60Cooldown() public {
        (,, uint256 minRedeemDuration, uint256 maxRedeemDuration) =
        getRedeemParameter();
        uint256 duration = (maxRedeemDuration - minRedeemDuration) * 60 / 100;
        duration += minRedeemDuration;
        uint256 balance = kza.balanceOf(alice);
        convert(alice, balance);
        redeem(alice, balance, duration);
        ifRedeemAmountMatch(alice, balance, duration);
    }
    //test finalizeRedeem

    function testFinalizeRedeemMax() public {
        uint256 duration = xkza.maxRedeemDuration();
        uint256 balance = kza.balanceOf(alice);
        convert(alice, balance);
        redeem(alice, balance, duration);
        skip(duration);
        vm.prank(alice);
        xkza.finalizeRedeem(0);
        assertEq(balance, kza.balanceOf(alice));
    }

    function testFinalizeRedeemMin() public {
        uint256 duration = xkza.minRedeemDuration();
        uint256 minRatio = xkza.minRedeemRatio();
        uint256 balance = kza.balanceOf(alice);
        convert(alice, balance);
        redeem(alice, balance, duration);
        skip(duration);
        vm.prank(alice);
        xkza.finalizeRedeem(0);
        assertEq(minRatio * balance / 100, kza.balanceOf(alice));
    }

    //test cancelRedeem
    function testCancelRedeemImmediate() public {
        uint256 duration = xkza.minRedeemDuration();
        uint256 minRatio = xkza.minRedeemRatio();
        uint256 balance = kza.balanceOf(alice);
        convert(alice, balance);
        redeem(alice, balance, duration);
        vm.prank(alice);
        xkza.cancelRedeem(0);
        assertEq(xkza.balanceOf(alice), balance);
    }

    function testCancelRedeemPostCooldown() public {
        uint256 duration = xkza.minRedeemDuration();
        uint256 minRatio = xkza.minRedeemRatio();
        uint256 balance = kza.balanceOf(alice);
        convert(alice, balance);
        redeem(alice, balance, duration);
        skip(duration);
        vm.prank(alice);
        xkza.cancelRedeem(0);
        assertEq(xkza.balanceOf(alice), balance);
    }

    // test admin update
    function testAddWhitelist() public {
        vm.prank(GOV);
        xkza.updateTransferWhitelist(alice, true);
        convert(alice, 1);
        vm.prank(alice);
        xkza.transfer(bob, 1);
        assertEq(xkza.balanceOf(bob), 1);
    }

    function testRemoveWhitelist() public {
        vm.prank(GOV);
        xkza.updateTransferWhitelist(alice, true);
        vm.prank(GOV);
        xkza.updateTransferWhitelist(alice, false);
        vm.prank(alice);
        string memory expRevertMessage = "xToken does not allow transfer";
        vm.expectRevert(abi.encodePacked(expRevertMessage));
        xkza.transfer(bob, 1);
    }

    function testRemoveWhitelistFromSelfFail() public {
        string memory expRevertMessage = "updateTransferWhitelist: Cannot remove xToken from whitelist";
        vm.expectRevert(abi.encodePacked(expRevertMessage));
        vm.prank(GOV);
        xkza.updateTransferWhitelist(address(xkza), false);
    }

    function testAddWhitelistNOTOWNER() public {
        vm.prank(alice);
        string memory expRevertMessage = "Ownable: caller is not the owner";
        vm.expectRevert(abi.encodePacked(expRevertMessage));
        xkza.updateTransferWhitelist(alice, true);
    }

    //validation
  function itConvertAmountMatch(address to, uint256 amount) public {
    assertEq(xkza.balanceOf(to), amount);
  }

  function ifRedeemAmountMatch(address user, uint256 redeemAmount, uint256 duration) public {
    (uint256 minRedeemRatio, uint256 maxRedeemRatio, uint256 minRedeemDuration, uint256 maxRedeemDuration) =
        getRedeemParameter();
    assert(duration >= minRedeemDuration);
    // just test the first index
    (uint256 kzaAmount, uint256 xAmount, uint256 endPeriod) = xkza.getUserRedeem(user, 0);
    assertEq(xAmount, redeemAmount);
    uint256 proportion =  minRedeemRatio + 
    ((maxRedeemRatio - minRedeemRatio) * (duration - minRedeemDuration) / (maxRedeemDuration - minRedeemDuration));
    assertEq(kzaAmount, proportion * xAmount / 100); // precision is 100
  }

    // helper function
    function convert(address user, uint256 amount) public override {
        vm.prank(user);
        return xkza.convert(amount);
    }

    function convertTo(address from, address to, uint256 amount) public  {
        vm.prank(from);
        return xkza.convertTo(amount, to);
    }

    function redeem(address user, uint256 xAmount, uint256 duration) public {
        vm.prank(user);
        xkza.redeem(xAmount, duration);
    }

    // redeemIndex is user specific, start from 0
    function cancelRedeem(address user, uint256 redeemIndex) public {
        vm.prank(user);
        xkza.cancelRedeem(redeemIndex);
    }

    function getRedeemParameter() public returns(uint256 minRedeemRatio, uint256 maxRedeemRatio, uint256 minRedeemDuration, uint256 maxRedeemDuration) {
        minRedeemRatio = xkza.minRedeemRatio();
        maxRedeemRatio = xkza.maxRedeemRatio();
        minRedeemDuration = xkza.minRedeemDuration();
        maxRedeemDuration = xkza.maxRedeemDuration();

    }


}