// SPDX-License-Identifier: MIT

// Invariants

// 1. The total suppy of DSC should always less than the collateral value

// 2. All our getter functions should never get reverted

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {console} from "forge-std/console.sol";
import {decentralisedstablecoin} from "../../src/DecentralisedStableCoin.sol";
import {DeployDsc} from "../../script/DeployDSC.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is StdInvariant, Test {
    HelperConfig helper;
    DSCEngine engine;
    DeployDsc deploy;
    decentralisedstablecoin coin;
    address weth;
    address wbtc;
    Handler handler;
    address User = makeAddr("User");

    function setUp() external {
        deploy = new DeployDsc();
        (coin, engine, helper) = deploy.run();
        (,, weth, wbtc,) = helper.activeNetworkConfig();
        handler = new Handler(engine, coin);
        // deal(address(weth), User, 10);
        // //deal(address(coin), , 10000);
        // deal(address(wbtc), User, 10);
        targetContract(address(handler));
    }

    function invariant_collateralgreaterThanDSC() public view {
        uint256 totalsupply = coin.totalSupply();
        uint256 wethsupply = IERC20(weth).balanceOf(address(engine));
        uint256 wbtcsupply = IERC20(wbtc).balanceOf(address(engine));
        uint256 wethvalue = engine.getTokenValueInUSD(weth, wethsupply);
        uint256 wbtcvalue = engine.getTokenValueInUSD(wbtc, wbtcsupply);
        assert(wethvalue + wbtcvalue >= totalsupply);
    }
}
