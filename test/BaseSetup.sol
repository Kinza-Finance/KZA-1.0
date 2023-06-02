// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import {Utils} from "./utils/Utils.sol";
import {KZA} from "../src/contracts/KZA/KZA.sol";
import {XKZA} from "../src/contracts/KZA/XKZA.sol";
import {Minter} from "../src/contracts/KZA/Minter.sol";
import {Voter} from "../src/contracts/KZA/Voter.sol";
import {VoteLogic} from "../src/contracts/KZA/VoteLogic.sol";
import {BribeAssetRegistry} from "../src/contracts/KZA/BribeAssetRegistry.sol";
import {VestingEscrow} from "../src/contracts/KZA/VestingEscrow.sol";
import {KZADistributor} from "../src/contracts/KZA/KZADistributor.sol";

import {ReserveFeeDistributor} from "../src/contracts/integration/ReserveFeeDistributor.sol";

import {AggregateBribe} from "../src/contracts/KZA/AggregateBribe.sol";
import {RewardsVault} from "../src/contracts/integration/RewardsVault.sol";

import {LockTransferStrategy} from "../src/contracts/integration/LockTransferStrategy.sol";

import {RewardsController} from "../src/contracts/lending/RewardsController.sol";
import {EmissionManager} from "../src/contracts/lending/EmissionManager.sol";
import {MockPool} from "../src/contracts/mock/MockPool.sol";
import {MockERC20} from "../src/contracts/mock/MockERC20.sol";
import {MockScaledERC20} from "../src/contracts/mock/MockScaledERC20.sol";
import {MockRewardOracle} from "../src/contracts/mock/MockRewardOracle.sol";

import "../src/libraries/DataTypes.sol";

contract BaseSetup is Test {

    address constant DEPLOYER =
        address(0xe155068F9B746dc3068FE3D3370Cfca6aB6FB8F6);
    address constant GOV = 
        address(0xCc3fBD1ff6E1e2404D0210823C78ae74085b6235);
    address constant INIT_TOKENHOLDER = 
        address(0xCc3fBD1ff6E1e2404D0210823C78ae74085b6235);

    
    MockERC20 usdc = new MockERC20();
    MockERC20 usdt = new MockERC20();
    address USDC = address(usdc);
    address USDT = address(usdt);
        

    // common constant
    uint256 DEFAULT = 100;
    uint256 PRECISION = 10000; 
    uint256 DURATION = 7 days;

    KZA kza;
    XKZA xkza;
    VestingEscrow ve;
    Minter minter;
    Voter voter;
    VoteLogic votelogic;
    BribeAssetRegistry registry;

    KZADistributor dist;
    ReserveFeeDistributor rdist;
    EmissionManager em;
    RewardsController rc;
    MockPool mp;
    RewardsVault rv;
    LockTransferStrategy ts;

    MockERC20 bribeTokenA;
    MockERC20 bribeTokenB;
    MockRewardOracle ro;

    //derived
    AggregateBribe eb;
    AggregateBribe eb_usdt;

    Utils internal utils;
    address payable[] internal users;

    address internal alice;
    address internal bob;

    address internal borrower1;
    address internal borrower2;
    address treasury;

    function setUp() public virtual {
        utils = new Utils();
        users = utils.createUsers(5);

        alice = users[0];
        vm.label(alice, "Alice");
        bob = users[1];
        vm.label(bob, "Bob");
        borrower1 = users[2];
        vm.label(borrower1, "borrower1");
        borrower2 = users[3];
        vm.label(borrower2, "borrower2");

        // deployment KZA
        vm.prank(DEPLOYER);
        kza = new KZA(GOV);
        
        treasury = GOV;
        //  deployment of XKZA
        vm.prank(DEPLOYER);
        xkza = new XKZA(address(kza), GOV);
        vm.prank(alice);
        kza.approve(address(xkza), 2 ** 256 - 1);
        vm.prank(bob);
        kza.approve(address(xkza), 2 ** 256 - 1);

        // some mock
        
        
        //deployment of emissionManager
        vm.prank(DEPLOYER);
        em = new EmissionManager(GOV);
        // deployment of RewardsController 
        vm.prank(DEPLOYER);
        rc = new RewardsController(address(em));
        vm.prank(GOV);
        em.setRewardsController(address(rc));
        vm.prank(DEPLOYER);
        mp = new MockPool();
        setUpMockPool();

        // deployment of VestingEscrow
        vm.prank(DEPLOYER);
        ve = new VestingEscrow(address(kza), GOV);

        // deployment of Minter
        vm.prank(DEPLOYER);
        minter = new Minter(address(mp), address(kza), GOV);

        // deployment of VoteLogic
        vm.prank(DEPLOYER);
        votelogic = new VoteLogic(address(xkza), GOV);
        // deployment of bribeAssetRegistry
        vm.prank(DEPLOYER);
        registry = new BribeAssetRegistry(GOV);
        // deployment of Voter
        vm.prank(DEPLOYER);
        voter = new Voter(address(xkza), address(minter), address(votelogic), address(registry), GOV);

        
        bribeTokenA = new MockERC20();
        bribeTokenB = new MockERC20();
        ro = new MockRewardOracle();

        // deployment of dTokenDistributor
        vm.prank(DEPLOYER);
        dist = new KZADistributor(GOV, address(kza), address(minter), address(mp));
        vm.prank(DEPLOYER);
        rdist = new ReserveFeeDistributor(GOV, treasury, address(mp), address(voter));
        // deployment of rewardVault
        vm.prank(DEPLOYER);
        rv = new RewardsVault(GOV, address(dist), address(kza));
        // deployment of transferStrategy
        vm.prank(DEPLOYER);
        ts = new LockTransferStrategy(address(rc), GOV, address(rv),address(xkza));
        
        //setup voter for minter
        vm.prank(GOV);
        minter.updateVoter(address(voter));
        vm.prank(GOV);
        minter.updateDistributor(address(dist));

        //setup voter for xkza
        vm.prank(GOV);
        xkza.updateVoter(address(voter));
        // setup transfer strategy for vault
        vm.prank(GOV);
        rv.updateTransferStrat(address(ts));
        // setup vault & emissionManager for dtokenDistributor
        vm.prank(GOV);
        dist.setVault(address(rv));
        vm.prank(GOV);
        dist.setEmissionManager(address(em));
        setUpRewardController();
        //setup Distributor as emission admin
        vm.prank(GOV);
        em.setEmissionAdmin(address(kza), address(dist));

        vm.prank(GOV);
        kza.initialMint(INIT_TOKENHOLDER);
        vm.prank(GOV);
        kza.setBribeMinter(address(minter));
        // // create underlying which can be voted
        vm.prank(GOV);
        voter.pushUnderlying(USDC);
        vm.prank(GOV);
        voter.pushUnderlying(USDT);
        
        eb = AggregateBribe(address(voter.bribes(USDC)));
        eb_usdt = AggregateBribe(address(voter.bribes(USDT)));
        // set current timestamp - foundry has a default of 1
        skip(1683000000);
        minter.update_period();
    }

    function facuet(address user, uint256 amount) public virtual {
    vm.prank(INIT_TOKENHOLDER);
    kza.transfer(user, amount * 10** 18);
    }

    function convert(address user, uint256 amount) public virtual {
        vm.prank(user);
        return xkza.convert(amount);
    }

    function setupVoter(uint256 aliceRatio, uint256 bobRatio) public virtual {
        BaseSetup.facuet(alice, aliceRatio);
        BaseSetup.facuet(bob, bobRatio);
        // set up alice bob as voter
        convert(alice, aliceRatio);
        convert(bob, bobRatio);
    }
    function singlePoolVote(address delegate, address user, address underlying) public virtual {
        vm.prank(delegate);
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
    }

    function doublePoolVote(address delegate, address user, uint256 fRatio, uint256 sRatio) public virtual {
        vm.prank(delegate);
        address[] memory _poolVote = new address[](2);
        uint256[] memory _weight = new uint256[](2);
        _poolVote[0] = USDC;
        _poolVote[1] = USDT;
        //weight is relative so can be any number for a single pool
        _weight[0] = fRatio;
        _weight[1] = sRatio;
        voter.vote(user, _poolVote, _weight);
        uint256 used = votelogic.balanceOf(user);
        //assert
        assertEq(voter.lastVoted(user), block.timestamp);
        assertEq(voter.usedWeights(user), used);
        assertEq(voter.poolVote(user, 0), USDC);
        assertEq(voter.poolVote(user, 1), USDT);
    }

    function setUpReward(address target) public {
        DataTypes.RewardsConfigInput[] memory inputs = new DataTypes.RewardsConfigInput[](1);
        DataTypes.RewardsConfigInput memory input;
        input.asset = target;
        input.reward = address(kza);
        input.transferStrategy = ITransferStrategyBase(address(ts));
        input.rewardOracle = IEACAggregatorProxy(address(ro));
        inputs[0] = input;
        vm.prank(GOV);
        em.setEmissionAdmin(address(kza), GOV);
        vm.prank(GOV);
        em.configureAssets(inputs);
    }
    function setUpRewardController() public {
        // asset is usdc variableDebtToken
        address vdToken = mp.getReserveData(USDC).variableDebtTokenAddress;
        setUpReward(vdToken);
        address sdToken = mp.getReserveData(USDC).stableDebtTokenAddress;
        setUpReward(sdToken);
        address aToken = mp.getReserveData(USDC).aTokenAddress;
        setUpReward(aToken);

        vdToken = mp.getReserveData(USDT).variableDebtTokenAddress;
        setUpReward(vdToken);
        sdToken = mp.getReserveData(USDT).stableDebtTokenAddress;
        setUpReward(sdToken);
        aToken = mp.getReserveData(USDT).aTokenAddress;
        setUpReward(aToken);
        
    }

    function setUpMockPool() public {
        mp.pushReserve(USDC);
        address atoken = address(new MockScaledERC20());
        address vdtoken = address(new MockScaledERC20());
        address sdtoken = address(new MockScaledERC20());
        mp.changeDTokenStableReserveList(USDC, sdtoken);
        mp.changeDTokenVariableReserveList(USDC, vdtoken);
        mp.changeATokenReserveList(USDC, atoken);

        atoken = address(new MockScaledERC20());
        vdtoken = address(new MockScaledERC20());
        sdtoken = address(new MockScaledERC20());
        mp.pushReserve(USDT);
        mp.changeDTokenStableReserveList(USDT, sdtoken);
        mp.changeDTokenVariableReserveList(USDT, vdtoken);
        mp.changeATokenReserveList(USDT, atoken);

        assertEq(MockERC20(vdtoken).decimals(), 18);

        assertEq(mp.getReservesList().length, 2);

    }



}