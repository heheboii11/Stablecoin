// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title Decentlizedstablecoin
 * @author Karthik
 * Colleteral: Exogenous
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * This contract will be governed by DSCEngine, this contract is just a ERC20 version of the project
 */

contract decentralisedstablecoin is ERC20Burnable, Ownable {
    address public immutable Owner;

    error Stablecoin__zerocoins();
    error Stablecoin__lesscoins();
    error Stablecoin__zeroaddress();

    constructor() ERC20("heheboii", "hehe") {
        //msg.sender == owner;
    }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 _balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert Stablecoin__zerocoins();
        }
        if (_amount > _balance) {
            revert Stablecoin__lesscoins();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert Stablecoin__zeroaddress();
        }
        if (_amount <= 0) {
            revert Stablecoin__zerocoins();
        }
        _mint(_to, _amount);
        return true;
    }
}
