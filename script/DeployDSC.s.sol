// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {decentralisedstablecoin} from "../src/DecentralisedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployDsc is Script {
    address[] public tokenAddress;
    address[] public priceFeedAddress;

    function run() external returns (decentralisedstablecoin, DSCEngine, HelperConfig) {
        HelperConfig helperconfig = new HelperConfig();
        (address wethPriceFeed, address wbtcPriceFeed, address wethAddress, address wbtcAddress, uint256 deployerKey) =
            helperconfig.activeNetworkConfig();

        tokenAddress = [wethAddress, wbtcAddress];
        priceFeedAddress = [wethPriceFeed, wbtcPriceFeed];
        //uint8 dec = helperconfig.decimal();

        vm.startBroadcast(deployerKey);
        decentralisedstablecoin coin = new decentralisedstablecoin();
        DSCEngine engine = new DSCEngine(tokenAddress, priceFeedAddress, address(coin));
        coin.transferOwnership(address(engine));
        vm.stopBroadcast();
        return (coin, engine, helperconfig);
    }
}
