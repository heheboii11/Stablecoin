// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {console} from "forge-std/console.sol";
import {decentralisedstablecoin} from "../../src/DecentralisedStableCoin.sol";
import {DeployDsc} from "../../script/DeployDSC.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract Handler is Test {
    DSCEngine engine;
    decentralisedstablecoin coin;
    ERC20Mock weth;
    ERC20Mock wbtc;
    ERC20Mock erc;
    uint256 MaxAmountOfCollateral = type(uint96).max;
    //mapping(address => ERC20Mock) private userCollateral;

    constructor(DSCEngine _engine, decentralisedstablecoin _coin) {
        engine = _engine;
        coin = _coin;
        address[] memory CollateralAddress = engine.getCollateraddress();
        weth = ERC20Mock(CollateralAddress[0]);
        wbtc = ERC20Mock(CollateralAddress[1]);
    }

    function mintdsc(uint256 amount) public {
        (uint256 totaldscminted, uint256 collateralvalue) = engine.getAccountinfo(msg.sender);
        console.log("totaldscalready:", totaldscminted);
        int256 MaxDsccanmint = ((int256(collateralvalue) / 2) - int256(totaldscminted));
        if (MaxDsccanmint < 0) {
            return;
        }

        amount = bound(amount, 0, uint256(MaxDsccanmint));
        if (amount == 0) {
            return;
        }
        console.log("maxdsc:", uint256(MaxDsccanmint));
        //console.log("collateral:", address(userCollateral[msg.sender]));
        vm.startPrank(msg.sender);
        engine.MintDSC(amount);
        vm.stopPrank();
    }

    function depositCollateral(uint256 CollateralSeed, uint256 amountofCollateral) public {
        ERC20Mock collateral = getCollateralSeed(CollateralSeed);
        amountofCollateral = bound(amountofCollateral, 1, MaxAmountOfCollateral);
        console.log("ADDRESS:", address(collateral));
        //userCollateral[msg.sender] = collateral;
        vm.startPrank(msg.sender);
        //collateral.mint(msg.sender, amountofCollateral);
        deal(address(collateral), msg.sender, amountofCollateral);
        ERC20Mock(collateral).approve(address(engine), amountofCollateral);
        console.log("Balance:", ERC20Mock(collateral).balanceOf(address(msg.sender)));
        engine.depositCollateral(address(collateral), amountofCollateral);
        vm.stopPrank();
    }

    function Collateralredeem(uint256 CollateralSeed, uint256 amountofCollateral) public {
        ERC20Mock collateral = getCollateralSeed(CollateralSeed);
        //ERC20Mock collateral = userCollateral[msg.sender];
        console.log(address(collateral));
        uint256 Dscminted = engine.getDScmintedbyUser(msg.sender);
        uint256 DScValueInCollateral = engine.getUSDValueintoken(address(collateral), Dscminted);
        console.log("DScValueInCollateral:", DScValueInCollateral);
        uint256 Collateralvaluefordsc = engine.getCollateralwithUser(address(collateral), msg.sender);
        console.log("Collateralvaluefordsc,", Collateralvaluefordsc);
        if (Collateralvaluefordsc == 0) {
            return;
        }
        uint256 MaxRedeem = (Collateralvaluefordsc - (DScValueInCollateral * 2));
        console.log("maxredeem:", MaxRedeem);
        /// in here we have tweek a bit that we have to check DSC that are already minted and deduct from maxAmount

        amountofCollateral = bound(amountofCollateral, 0, MaxRedeem);
        if (amountofCollateral == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        ERC20Mock(address(coin)).approve(address(engine), Dscminted);
        engine.redeemcollateral(address(collateral), amountofCollateral);
        vm.stopPrank();
    }

    //helper functions

    function getCollateralSeed(uint256 CollateralSeed) private view returns (ERC20Mock) {
        if (CollateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
