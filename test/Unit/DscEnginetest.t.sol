// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {decentralisedstablecoin} from "../../src/DecentralisedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {Test} from "forge-std/Test.sol";
import {DeployDsc} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {console} from "forge-std/console.sol";
import {MockV3Aggregator} from "../Mocks/MockV3Aggregator.sol";

contract TestDSCEngine is Test {
    DSCEngine engine;
    DeployDsc deploy;
    HelperConfig helper;
    decentralisedstablecoin coin;
    uint256 DScminted;
    uint256 collateralValue;
    address public weth;
    address public ethpricefeed;
    address public btcpricefeed;
    uint256 public constant Eth_amount = 9;
    uint256 public TokenInUsd;
    address public User = makeAddr("user");
    address bob = makeAddr("bob");
    uint256 public constant Zero = 0;
    uint256 public constant Dscmint = 10;
    uint256 public constant DscMaxmint = 9900;
    uint256 public constant DscMediumMint = 5000;
    uint256 public constant Eth_amount_redeem = 1;
    uint256 private constant PRECISION = 1e18;

    ///////////////////
    /////Modifiers /////
    //////////////////

    modifier depositCollateral(address token, uint256 amount) {
        vm.startPrank(User);
        ERC20Mock(weth).approve(address(engine), Eth_amount);
        engine.depositCollateral(token, amount);
        vm.stopPrank();
        _;
    }

    modifier MintDsc(uint256 dscamount) {
        vm.startPrank(User);
        engine.MintDSC(dscamount);
        vm.stopPrank();
        _;
    }

    modifier redeemCollateral(address collateraltoredeem, uint256 amountToRedeem) {
        vm.startPrank(User);
        console.log(engine.getTokendepositswithuser(User, weth));
        engine.redeemcollateral(collateraltoredeem, amountToRedeem);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        helper = new HelperConfig();
        deploy = new DeployDsc();
        (coin, engine, helper) = deploy.run();
        (ethpricefeed, btcpricefeed, weth,,) = helper.activeNetworkConfig();
        deal(address(weth), User, 10);
        deal(address(coin), bob, 10000);
    }

    ///////////////////
    /////Constructor Tests /////
    //////////////////
    address[] public pricefeeds;
    address[] public tokenadd;

    function testConstructorIfTokenlengthnotMatch() public {
        pricefeeds.push(ethpricefeed);
        pricefeeds.push(btcpricefeed);
        tokenadd.push(weth);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndpriceFeedAddressesAreNotEqual.selector);
        new DSCEngine(tokenadd, pricefeeds, address(coin));
    }

    ///////////////////
    /////Price Tests  /////
    //////////////////

    function testTokeninUsd() public {
        TokenInUsd = engine.getTokenValueInUSD(weth, Eth_amount);
        assertEq(TokenInUsd, 18000);
    }

    function testgetUSDValueInUsd() public {
        uint256 Usdamount = 100 ether;
        uint256 actualtoken = 0.05 ether;
        uint256 UsdInToken = engine.getUSDValueintoken(weth, Usdamount);
        assertEq(actualtoken, UsdInToken);
    }
    ///////////////////
    /////deposit test  /////
    //////////////////

    function testDepositCollateralwithZero() public {
        vm.expectRevert(DSCEngine.DSCEngine__ZeroAmount.selector);
        engine.depositCollateral(weth, Zero);
    }

    function testDepositCollateralwithNotAllowed() public {
        //
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        engine.depositCollateral(address(0), Eth_amount);
    }

    function testDepositCollateral() public {
        vm.startPrank(User);
        ERC20Mock(weth).approve(address(engine), Eth_amount);
        engine.depositCollateral(weth, Eth_amount);
        vm.stopPrank();
    }

    function testdepositCollateralupdatesarray() public depositCollateral(weth, Eth_amount) {
        collateralValue = engine.getTokendepositswithuser(User, weth);
        (DScminted,) = engine.getAccountinfo(User);
        assertEq(DScminted, Zero);
        assertEq(collateralValue, Eth_amount);
    }

    function testMintDscupdatesArray() public depositCollateral(weth, Eth_amount) MintDsc(Dscmint) {
        (DScminted,) = engine.getAccountinfo(User);
        assertEq(DScminted, Dscmint);
    }

    function testredeemcollateral()
        public
        depositCollateral(weth, Eth_amount)
        MintDsc(Dscmint)
        redeemCollateral(weth, Eth_amount_redeem)
    {
        collateralValue = engine.getTokendepositswithuser(User, weth);
        assertEq(collateralValue, 8);
    }

    function testLiquidation() public depositCollateral(weth, Eth_amount) MintDsc(DscMediumMint) {
        MockV3Aggregator(ethpricefeed).updateAnswer(800e8);

        vm.startPrank(bob);
        ERC20Mock(address(coin)).approve(address(engine), 10000);

        engine.liquidate(User);
        vm.stopPrank();
    }

    function testliquidationrevertsIfHealthisMorethanMin()
        public
        depositCollateral(weth, Eth_amount)
        MintDsc(Dscmint)
    {
        MockV3Aggregator(ethpricefeed).updateAnswer(1500e8);
        vm.startPrank(bob);
        ERC20Mock(address(coin)).approve(address(engine), 10000);
        vm.expectRevert();
        engine.liquidate(User);
        vm.stopPrank();
    }

    function testhealthfactorMax() public depositCollateral(weth, Eth_amount) {
        uint256 health = engine.gethealthFactor(User);
        assertEq(health, type(uint256).max);
    }

    function testhealthfactor() public depositCollateral(weth, Eth_amount) MintDsc(DscMediumMint) {
        uint256 health = engine.gethealthFactor(User);
        assertEq(health, 18e17);
    }

    function testGetAccountCollateralValue() public depositCollateral(weth, Eth_amount) {
        // Mock ETH price feed
        // uint256 ethPrice = 2000e8; // ETH price in USD
        // MockV3Aggregator(ethpricefeed).updateAnswer(int256(ethPrice));

        // Calculate expected collateral value
        uint256 expectedCollateralValue = Eth_amount * engine.getpriceofToken(weth);
        console.log(Eth_amount);

        // Get the actual collateral value
        uint256 actualCollateralValue = engine.getAccountCollateralValue(User);
        console.log(actualCollateralValue);

        // Verify
        assertEq(actualCollateralValue, expectedCollateralValue);
    }

    function testBurnDsc() public depositCollateral(weth, Eth_amount) MintDsc(DscMediumMint) {
        vm.startPrank(User);
        vm.expectRevert(DSCEngine.DSCEngine__ZeroAmount.selector);
        engine.burnDsc(0);
        vm.stopPrank();
    }

    function testburnDscAndDscarrayUpdates() public depositCollateral(weth, Eth_amount) MintDsc(DscMediumMint) {
        vm.startPrank(User);
        ERC20Mock(address(coin)).approve(address(engine), Dscmint);
        engine.burnDsc(Dscmint);
        vm.stopPrank();
        (DScminted,) = engine.getAccountinfo(User);
        assertEq(DScminted, DscMediumMint - Dscmint);
    }
}
