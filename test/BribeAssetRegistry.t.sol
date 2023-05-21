import "./BaseSetup.sol";

contract BribeAssetRegistryTest is Test, BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    function testAddAsset() public {
        vm.prank(GOV);
        registry.addAsset(address(bribeTokenA));
        assertEq(registry.isWhitelisted(address(bribeTokenA)), true);
    }

    function testAddAssetNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        registry.addAsset(address(bribeTokenA));
    }

    function testRemoveAsset() public {
        vm.prank(GOV);
        registry.addAsset(address(bribeTokenA));
        vm.prank(GOV);
        registry.removeAsset(address(bribeTokenA));
        assertEq(registry.isWhitelisted(address(bribeTokenA)), false);

    }

    function testRemoveAssetNonOnwer() public {
        vm.prank(GOV);
        registry.addAsset(address(bribeTokenA));
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        registry.removeAsset(address(bribeTokenA));
        

    }
    
}