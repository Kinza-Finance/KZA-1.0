import "./BaseSetup.sol";

contract BribeAssetRegistryTest is Test, BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    function testAddAsset() public {
        vm.prank(GOV);
        registry.addAsset(USDC, address(bribeTokenA));
        assertEq(registry.isWhitelisted(USDC, address(bribeTokenA)), true);
    }

    function testAddAssetNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        registry.addAsset(USDC, address(bribeTokenA));
    }

    function testRemoveAsset() public {
        vm.prank(GOV);
        registry.addAsset(USDC, address(bribeTokenA));
        vm.prank(GOV);
        registry.removeAsset(USDC, address(bribeTokenA));
        assertEq(registry.isWhitelisted(USDC, address(bribeTokenA)), false);

    }

    function testRemoveAssetNonOnwer() public {
        vm.prank(GOV);
        registry.addAsset(USDC, address(bribeTokenA));
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        registry.removeAsset(USDC, address(bribeTokenA));
        

    }
    
}