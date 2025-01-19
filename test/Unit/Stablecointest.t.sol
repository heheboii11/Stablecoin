// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {decentralisedstablecoin} from "../../src/DecentralisedStableCoin.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract TestStablecoin is Test {
    decentralisedstablecoin stablecoin;
    //address owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address bob = address(1);
    address zero = address(0);
    uint256 intial_tokens = 10000;

    function setUp() public {
        vm.prank(bob);
        stablecoin = new decentralisedstablecoin();
        vm.prank(bob);
        stablecoin.mint(bob, intial_tokens);

        // vm.deal(bob, intial_tokens);
    }

    // function testburn() public {
    //     vm.prank(bob);
    //     vm.expectRevert();
    //     stablecoin.burn(0);
    // }

    function testburnlesstokens() public {
        vm.prank(bob);
        vm.expectRevert();
        stablecoin.burn(1000001);
    }

    function testburn() public {
        vm.prank(bob);
        vm.expectRevert();
        stablecoin.burn(0);
    }

    function testmintToZeroAddress() public {
        vm.prank(bob);
        vm.expectRevert();
        stablecoin.mint(address(0), 10);
    }

    function testZerocoinmint() public {
        vm.prank(bob);
        vm.expectRevert();
        stablecoin.mint(address(12), 0);
    }

    function testBalanceOfUser() public {
        //console.log(balanceOf(bob));
        //vm.prank(bob);
    }
}
