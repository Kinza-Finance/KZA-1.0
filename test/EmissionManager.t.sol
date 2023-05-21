import "./BaseSetup.sol";
import "../src/interfaces/IEACAggregatorProxy.sol";
import "../src/interfaces/ITransferStrategyBase.sol";

contract EmissionManagerTest is Test, BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    function testSetTransferStratNonContract() public {
        vm.prank(GOV);
        em.setEmissionAdmin(address(kza), GOV);
        vm.prank(GOV);
        address transferStrat = address(1);
        vm.expectRevert("STRATEGY_MUST_BE_CONTRACT");
        em.setTransferStrategy(address(kza), ITransferStrategyBase(transferStrat));
    }

    function testSetTransferStrat() public {
        vm.prank(GOV);
        em.setEmissionAdmin(address(kza), GOV);
        vm.prank(GOV);
        address transferStrat = address(ts);
        em.setTransferStrategy(address(kza), ITransferStrategyBase(transferStrat));
        assertEq(address(rc.getTransferStrategy(address(kza))), transferStrat);
    }

    function testSetSetRewardOracleNonContract() public {
        vm.prank(GOV);
        em.setEmissionAdmin(address(kza), GOV);
        vm.prank(GOV);
        address oracle = address(1);
        // since the oracle does not have latestAnswer > 0
        vm.expectRevert();
        em.setRewardOracle(address(kza), IEACAggregatorProxy(oracle));
    }

    function testSetSetRewardOracle() public {
        vm.prank(GOV);
        em.setEmissionAdmin(address(kza), GOV);
        vm.prank(GOV);
        // can be any address
        address oracle = address(ro);
        em.setRewardOracle(address(kza), IEACAggregatorProxy(oracle));
        assertEq(rc.getRewardOracle(address(kza)), address(oracle));
    }


    function testSetDistributionEnd() public {
        uint32 distributionEnd = uint32(block.timestamp) + uint32(1 days);
        address token = mp.getReserveData(USDC).variableDebtTokenAddress;
        // reward KZA's risk admin
        vm.prank(GOV);
        em.setEmissionAdmin(address(kza), GOV);
        vm.prank(GOV);
        em.setDistributionEnd(token, address(kza),  distributionEnd);
        (,,, uint256 DistributionEndFromContract) = rc.getRewardsData(token, address(kza));
        assertEq(distributionEnd, uint32(DistributionEndFromContract));

    }

    function testSetEmissionPerSecond() public {
        // reward KZA's risk admin
        uint88 emissionPerSecond = 1;
        vm.prank(GOV);
        em.setEmissionAdmin(address(kza), GOV);
        uint88[] memory rates = new uint88[](1);
        address[] memory rewards = new address[](1);
        rewards[0] = address(kza);
        rates[0] = emissionPerSecond;
        address token = mp.getReserveData(USDC).variableDebtTokenAddress;
        vm.prank(GOV);
        em.setEmissionPerSecond(token, rewards, rates);
        (, uint256 EmissionPerSecondFromContract,,) = rc.getRewardsData(token, address(kza));
        assertEq(emissionPerSecond,  uint88(EmissionPerSecondFromContract));
    }

    function testSetClaimer() public {
        vm.prank(GOV);
        address claim = alice;
        em.setClaimer(bob, alice);
        assertEq(rc.getClaimer(bob), alice);
    }

    function testSetEmissionAdmin() public {
        vm.prank(GOV);
        address admin = address(1);
        em.setEmissionAdmin(address(kza), admin);
        assertEq(em.getEmissionAdmin(address(kza)), admin);
    }

    function testSetRewardController() public {
        vm.prank(GOV);
        address controller = address(1);
        em.setRewardsController(controller);
        assertEq(address(em.getRewardsController()), controller);
    }
}