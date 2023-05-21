import "./BaseSetup.sol";

contract KZATest is Test, BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
        BaseSetup.facuet(alice, DEFAULT);
        BaseSetup.facuet(bob, DEFAULT);
  
    }

    function testUpdateMinter() public {
        updateMinter();
    }

    function testMint() public {
        updateMinter();
        uint256 toMint = DEFAULT * 10 ** 18;
        uint256 aliceBefore = kza.balanceOf(alice);
        vm.prank(GOV);
        kza.mint(alice, toMint);
        assertEq(kza.balanceOf(alice), aliceBefore + toMint);
    }

    function testOverMint() public {
        updateMinter();
        uint256 toMint = 100_000_000 * 10 ** 18;
        uint256 aliceBefore = kza.balanceOf(alice);
        vm.prank(GOV);
        vm.expectRevert("exceeds max supply");
        kza.mint(alice, toMint);
    }
    // test re-mint
    function testReInitialMint() public {
        string memory expRevertMessage = "initial mint is already done";
        vm.expectRevert(abi.encodePacked(expRevertMessage));
        vm.prank(GOV);
        kza.initialMint(alice);
    }

    //test transfer
    function testTransferZeroTokens() public {
    uint256 t = kza.balanceOf(alice);
    itTransfersAmountCorrectly(alice, bob, 0);
    }

    function testTransferAllTokens() public {
    uint256 t = kza.balanceOf(alice);
    itTransfersAmountCorrectly(alice, bob, t);
    }

  function testTransferHalfTokens() public {
    uint256 t = kza.balanceOf(alice);
    itTransfersAmountCorrectly(alice, bob, t / 2);
  }

  function testTransferOneToken() public {
    itTransfersAmountCorrectly(alice, bob, 1);
  }

  function testCannotTransferMoreThanAvailable() public {
    uint256 t = kza.balanceOf(alice);
    itRevertsTransfer({
      from: alice,
      to: bob,
      amount: t + 1,
      expRevertMessage: "ERC20: transfer amount exceeds balance"
    });
  }
    
    // assertion in transfer
    function itTransfersAmountCorrectly(
    address from,
    address to,
    uint256 amount
  ) public {
    uint256 fromBalance = kza.balanceOf(from);
    bool success = transferToken(from, to, amount);
    assertTrue(success);
  }

  function itRevertsTransfer(
    address from,
    address to,
    uint256 amount,
    string memory expRevertMessage
  ) public {
    vm.expectRevert(abi.encodePacked(expRevertMessage));
    transferToken(from, to, amount);
  }

  function updateMinter() public {
        vm.prank(GOV);
        kza.setBribeMinter(GOV);
        assertEq(kza.minter(), GOV);
  }
    // function
    function transferToken(
        address from,
        address to,
        uint256 transferAmount
    ) public returns (bool) {
        vm.prank(from);
        return kza.transfer(to, transferAmount);
    }
}