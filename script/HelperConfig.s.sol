// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {decentralisedstablecoin} from "../src/DecentralisedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {MockV3Aggregator} from "../test/Mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    struct NetworkConfig {
        address wethPriceFeed;
        address wbtcPriceFeed;
        address wethAddress;
        address wbtcAddress;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;
    uint8 public constant decimal = 8;
    int256 public constant Ethintialanswer = 2000e8;
    int256 public constant Btcintialanswer = 1000e8;
    uint256 private constant ANVILKEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wethAddress: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtcAddress: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wethPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator Ethmockaggregator = new MockV3Aggregator(decimal, Ethintialanswer);
        MockV3Aggregator Btcmockaggregator = new MockV3Aggregator(decimal, Btcintialanswer);
        ERC20Mock weth = new ERC20Mock("Weth", "WETH", msg.sender, uint256(Ethintialanswer));
        ERC20Mock wBtc = new ERC20Mock("WBtc", "WBTC", msg.sender, uint256(Btcintialanswer));
        vm.stopBroadcast();
        return NetworkConfig({
            wethPriceFeed: address(Ethmockaggregator),
            wbtcPriceFeed: address(Btcmockaggregator),
            wethAddress: address(weth),
            wbtcAddress: address(wBtc),
            deployerKey: ANVILKEY
        });
    }
}
