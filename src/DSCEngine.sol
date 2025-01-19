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

//import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {decentralisedstablecoin} from "./DecentralisedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/console.sol";
//import { OracleLib, AggregatorV3Interface } from "./libraries/OracleLib.sol";

/*
 * @title DSCEngine
 * @author Karthik
 * Colleteral: Exogenous
 *
 * This contract will be control the minting and burning of our stablecoin. This acts as heart of this project.
 */
contract DSCEngine is ReentrancyGuard {
    ///////////////////
    /////Errors  /////
    //////////////////

    error DSCEngine__ZeroAmount();
    error DSCEngine__TokenAddressesAndpriceFeedAddressesAreNotEqual();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorIsLessThan(uint256 healthfactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorIsMoreThan(uint256 healthfactor);

    ///////////////////
    /////Type Declarations/////
    //////////////////

    decentralisedstablecoin private immutable i_Dsc;

    ///////////////////
    /////StateVariables/////
    //////////////////

    mapping(address token => address s_pricefeeds) private s_pricefeeds;
    mapping(address user => mapping(address token => uint256 userdeposits)) private s_userdeposits;
    mapping(address user => uint256 DscMinted) private s_DscMinted;
    address[] private s_collateralAddress;
    uint256 private constant ADDITIONAL_PRECISON = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant PRECISION_DIVISION = 1e8;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    uint256[] private amountofcollateral; // State variable in storage for deducting and sending remaining collateral for the user after liquidation

    ///////////////////
    //// Events/////
    //////////////////

    event Collateraldeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed from, address indexed to, address indexed token, uint256 amount);
    event Dscburned(address indexed user, uint256 amount);

    ///////////////////
    /////Modifiers  /////
    //////////////////

    modifier MoreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__ZeroAmount();
        }
        _;
    }

    modifier IsallowedToken(address Token) {
        if (s_pricefeeds[Token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    constructor(address[] memory TokenAddresses, address[] memory priceFeedAddresses, address Dscaddress) {
        if (TokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndpriceFeedAddressesAreNotEqual();
        }
        for (uint256 i = 0; i < TokenAddresses.length; i++) {
            s_pricefeeds[TokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralAddress.push(TokenAddresses[i]);
        }

        i_Dsc = decentralisedstablecoin(Dscaddress);
    }

    //////////////////////////////
    /////EXternal Functions /////
    /////////////////////////////

    function depositCollateralAndMintDsc(address tokencollateraladdress, uint256 tokenamount, uint256 DscToBeMinted)
        external
        MoreThanZero(DscToBeMinted)
        IsallowedToken(tokencollateraladdress)
        nonReentrant
    {
        // With this function users can deposit their collateral and mint Dsc
        depositCollateral(tokencollateraladdress, tokenamount);
        MintDSC(DscToBeMinted);
    }

    /*
     * @param  tokencollateraladdress  the address of the token that gets deposited
     * @param   tokenamount   the amount of token that gets deposited.
     *  CEI: Checks, Effects and interactions
     */
    function depositCollateral(address tokencollateraladdress, uint256 tokenamount)
        public
        MoreThanZero(tokenamount)
        IsallowedToken(tokencollateraladdress)
        nonReentrant
    {
        s_userdeposits[msg.sender][tokencollateraladdress] += tokenamount;
        emit Collateraldeposited(msg.sender, tokencollateraladdress, tokenamount);
        bool succes = IERC20(tokencollateraladdress).transferFrom(msg.sender, address(this), tokenamount);
        if (!succes) {
            revert DSCEngine__TransferFailed();
        }
    }

    function MintDSC(uint256 DscToBeMinted) public MoreThanZero(DscToBeMinted) nonReentrant {
        s_DscMinted[msg.sender] += DscToBeMinted;
        _revertIfHealthFactorisBroken(msg.sender);
        bool mint = i_Dsc.mint(msg.sender, DscToBeMinted);
        if (!mint) {
            revert DSCEngine__MintFailed();
        }
    }
    /*
     *  @param Collateraltoberedeemed  This is the address of the collateral that needs to be redeemed
     *  @param amountOfCollateralredeem    This is the amount of the collateral that wants to be redeemed.
     * 
    */

    function redeemcollateral(address Collateraltoberedeemed, uint256 amountOfCollateralredeem)
        public
        MoreThanZero(amountOfCollateralredeem)
    {
        // with this function users redeem their collateral and, this will increaase the health factor
        _reedeemCollateral(address(this), msg.sender, Collateraltoberedeemed, amountOfCollateralredeem);
        _revertIfHealthFactorisBroken(msg.sender);
    }

    function burnDsc(uint256 Dscburn) public MoreThanZero(Dscburn) nonReentrant {
        // With this function the user can burn their Dsc and improve their health factor
        _burnDsc(msg.sender, msg.sender, Dscburn);
    }

    function redeemcollateralandburnDsc(
        address Collateraltoberedeemed,
        uint256 amountOfCollateralredeem,
        uint256 Dscburn
    ) external {
        burnDsc(Dscburn);
        redeemcollateral(Collateraltoberedeemed, amountOfCollateralredeem);
    }
    /*
     *
     * With this function anyone can liquidate the position of any user, if their health factor is less than 1.
     *  Logic in here is that if any user health factor is less than 1, any other user can liquidate the user by repaying his dsc debt and the other user gets the user
     * collateral provided by the user
     * suppose if a user bob; deposited $1000  of ETH and minted $200 worth of DSC
     * $1000 ETH --> $200 DSC; Health factor: 2.5 --> very good;
     *  But if ETH price comes down and his collateral value is now worth $300, then Health factor is 0.75, which is not the expected value and the system gets under collaterlised
     * Hence any one can pay the debt and get his collateral, but this has to happen when collateral value is <200% of DSC and >100 %
     * Hence liquidation can occur between >0.5 to <1
     * 
     */

    function liquidate(address user) external {
        uint256 healthfactor = _healthFactor(user);
        uint256 dscmintedbyuser = s_DscMinted[user];

        if (healthfactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsMoreThan(healthfactor);
        }
        if (healthfactor <= MIN_HEALTH_FACTOR / 2) {
            revert DSCEngine__HealthFactorIsLessThan(healthfactor);
        }
        //IInitial collateral: $100 ETH, $100 BTC, $100 SOL, backing $150 DSC.
        // Price drop: $70 ETH, $80 BTC, $50 SOL, now totaling $200 collateral.
        // Under-collateralized position requires $150 DSC debt repayment plus a 10% liquidation bonus, totaling $165.
        // From the $200 collateral, $165 is given to the liquidator.
        // Remaining $35 is divided across the three assets, providing ~$11.6 (or $12) worth per asset back to the user.
        // Any leftover collateral after this distribution goes to the liquidator.
        _burnDsc(msg.sender, user, dscmintedbyuser);
        accumulateCollateralValues(user, dscmintedbyuser);

        for (uint256 i = 0; i < s_collateralAddress.length; i++) {
            uint256 totalCollateraltokenamount = s_userdeposits[user][s_collateralAddress[i]];
            uint256 amountsenttoLdepositer = totalCollateraltokenamount - amountofcollateral[i];
            // console.log("amount sent to depositor", amountsenttoLdepositer);
            // console.log("amountofcollateral", amountofcollateral[i]);
            // //console.log("contract", IERC20(address(s_collateralAddress[i])).balanceOf(address(this)));

            _reedeemCollateral(address(this), user, s_collateralAddress[i], amountsenttoLdepositer);
            IERC20(s_collateralAddress[i]).transfer(msg.sender, amountofcollateral[i]);
            //_reedeemCollateral(address(this), msg.sender, s_collateralAddress[i], amountofcollateral[i]);
            // console.log("contract", IERC20(address(s_collateralAddress[i])).balanceOf(address(this)));
        }
    }

    // f
    /////////////////////////////////////////
    //////////public functions//////////////
    /////////////////////////////////////////

    function getTokenValueInUSD(address tokenAddress, uint256 tokenamount) public view returns (uint256) {
        AggregatorV3Interface priceFeedAddress = AggregatorV3Interface(s_pricefeeds[tokenAddress]);
        //console.log(priceFeedAddress);
        (, int256 price,,,) = priceFeedAddress.latestRoundData();
        uint256 tokenInUsd = ((uint256(price) * ADDITIONAL_PRECISON) * tokenamount) / PRECISION;
        return tokenInUsd;
    }

    function getUSDValueintoken(address tokenAddress, uint256 Dscamount) public view returns (uint256) {
        AggregatorV3Interface priceFeedAddress = AggregatorV3Interface(s_pricefeeds[tokenAddress]);
        //console.log(priceFeedAddress);
        (, int256 price,,,) = priceFeedAddress.latestRoundData();
        uint256 UsdValueInToken = (Dscamount * PRECISION) / (uint256(price) * ADDITIONAL_PRECISON);
        return UsdValueInToken;
    }

    function getAccountCollateralValue(address user) public view returns (uint256) {
        uint256 UsercollateralValue;
        //console.log(s_collateralAddress[0]);
        for (uint256 i = 0; i < s_collateralAddress.length; i++) {
            address token = s_collateralAddress[i];
            //console.log(token);
            uint256 tokenamountOfCollateral = s_userdeposits[user][token];
            uint256 tokencollateralValue = getTokenValueInUSD(token, tokenamountOfCollateral);
            //console.log(tokenamountOfCollateral);
            UsercollateralValue += tokencollateralValue;
            //console.log(UsercollateralValue);
        }
        return UsercollateralValue;
    }

    function getHealthFactor(address User) external view returns (uint256) {
        return _healthFactor(User);
    }

    /////////////////////////////////////////
    //////////Private & Internal functions///
    /////////////////////////////////////////

    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 DscWithUser, uint256 CollateralWithUser) = getAccountInformation(user);
        //console.log(DscWithUser, CollateralWithUser);
        if (DscWithUser == 0) return type(uint256).max;
        uint256 HealthFactor =
            (CollateralWithUser * LIQUIDATION_THRESHOLD * PRECISION) / (DscWithUser * LIQUIDATION_PRECISION);
        //console.log(HealthFactor);
        return HealthFactor;
    }

    function getAccountInformation(address user) private view returns (uint256 DscMinted, uint256 CollateralValue) {
        DscMinted = s_DscMinted[user];
        CollateralValue = getAccountCollateralValue(user);
        return (DscMinted, CollateralValue);
    }

    function accumulateCollateralValues(address user, uint256 dscmintedbyuser) internal {
        //uint256 LengthofCollateral = s_collateralAddress.length;
        delete amountofcollateral;
        uint256 UserCollateralValueattheTimeOfLiquidation = getAccountCollateralValue(user);
        uint256 amountUsergonnalost = dscmintedbyuser + ((dscmintedbyuser * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION);
        // uint256 ReturnCollateralofToken =
        //     UserCollateralValueattheTimeOfLiquidation - (amountUsergonnalost / LengthofCollateral); // Here we are using /lengthofcollateral  because we will use this directly use this number to send the remainng collateral to user.

        for (uint256 i = 0; i < s_collateralAddress.length; i++) {
            uint256 amount = getTokenValueInUSD(s_collateralAddress[i], s_userdeposits[user][s_collateralAddress[i]]); // eth-> 8000, btc-> 0,
            //console.log("amount", amount);
            uint256 percentage = amount * PRECISION / UserCollateralValueattheTimeOfLiquidation; // eth -> 100%, btc--> 0%; eth*1
            //console.log("percentage", percentage);
            uint256 ShareOfEachCollateral = (amountUsergonnalost * percentage) / PRECISION; // eth -> 8000, btc-> 0; 5500 from eth
            //console.log("share", ShareOfEachCollateral);
            uint256 tokenamounttodeduct = getUSDValueintoken(s_collateralAddress[i], ShareOfEachCollateral);
            //console.log("tokenamountdeeduct", tokenamounttodeduct);
            amountofcollateral.push(tokenamounttodeduct); // Push each amount into the storage array
        }
        // console.log(amountofcollateral[0]);
        // console.log("btc", amountofcollateral[1]);
    }

    function _burnDsc(address DscFrom, address OnbehalfOf, uint256 Dscburn) internal {
        s_DscMinted[OnbehalfOf] -= Dscburn;
        emit Dscburned(OnbehalfOf, Dscburn);
        bool success = i_Dsc.transferFrom(DscFrom, address(this), Dscburn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }

        i_Dsc.burn(Dscburn);
    }

    function _reedeemCollateral(
        address from,
        address to,
        address Collateraltoberedeemed,
        uint256 amountOfCollateralredeem
    ) internal {
        //console.log(s_userdeposits[from])
        require(
            s_userdeposits[to][Collateraltoberedeemed] >= amountOfCollateralredeem, "DSCEngine: Insufficient collateral"
        );

        s_userdeposits[to][Collateraltoberedeemed] -= amountOfCollateralredeem;
        emit CollateralRedeemed(from, to, Collateraltoberedeemed, amountOfCollateralredeem);

        bool redeem = IERC20(Collateraltoberedeemed).transfer(to, amountOfCollateralredeem);
        if (!redeem) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _revertIfHealthFactorisBroken(address user) internal view {
        uint256 HealthFactorofUser = _healthFactor(user);
        if (HealthFactorofUser < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsLessThan(HealthFactorofUser);
        }
    }

    /////////////////////////////////////////
    //////////getter functions///
    /////////////////////////////////////////
    function getAccountinfo(address user) external view returns (uint256 DscMinted, uint256 CollateralValue) {
        return (getAccountInformation(user));
    }

    function getTokendepositswithuser(address user, address token) external view returns (uint256) {
        return (s_userdeposits[user][token]);
    }

    function gethealthFactor(address user) external view returns (uint256) {
        return (_healthFactor(user));
    }

    function getpriceofToken(address tokenAddress) external view returns (uint256) {
        AggregatorV3Interface priceFeedAddress = AggregatorV3Interface(s_pricefeeds[tokenAddress]);

        (, int256 price,,,) = priceFeedAddress.latestRoundData();
        return (uint256(price) / PRECISION_DIVISION);
    }

    function getCollateraddress() external view returns (address[] memory) {
        return s_collateralAddress;
    }

    function getCollateralwithUser(address token, address user) external view returns (uint256) {
        return s_userdeposits[user][token];
    }

    function getDScmintedbyUser(address User) external view returns (uint256) {
        return s_DscMinted[User];
    }
}
// we created a erc20, then we have to design Dscengine such that it controls the minting and burning means it has to take care of colleteral and all, in scripts we will just deploy or interact with using them, so first we have make dscengine such that we can govern the coin
// dsc --> 1. get eth & btc prices using chainlink pricefeeds
// 2. Ltv should be 60 percent
// 3. liquidation is at 80 percent
// 4. here we are not focusing on lendiong protocol, we are just creating a stablecoin project where the user deposits colleteral and mints stablecoin and if LTV is 80 %, then he gets liqudated and gets the remaining 20%.
// 5. to make this happen whenever a person deposits colleteral and mints coins,
