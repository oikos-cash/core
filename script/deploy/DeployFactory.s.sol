// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import { Utils } from "../../src/libraries/Utils.sol";
import { IUniswapV3Pool } from "v3-core/interfaces/IUniswapV3Pool.sol";
import { IAddressResolver } from "../../src/interfaces/IAddressResolver.sol";
import { Deployer } from "../../src/Deployer.sol";
import { OikosFactory } from "../../src/factory/OikosFactory.sol";
import { VaultDeployParams, VaultDescription, ProtocolParameters, PresaleProtocolParams, Decimals } from "../../src/types/Types.sol";
import { PresaleFactory } from "../../src/factory/PresaleFactory.sol";


import { DeployerFactory } from "../../src/factory/DeployerFactory.sol"; 
import { ExtFactory } from "../../src/factory/ExtFactory.sol";
import { Resolver } from "../../src/Resolver.sol";
import { OikosDividends } from "../../src/controllers/OikosDividends.sol";
import { WETH9 } from "../../src/token/WETH9.sol";

interface IWETH {
    function mintTo(address to, uint256 amount) external;
    function deposit() external payable;
    function depositTo(address receiver) external payable;
    function transfer(address to, uint value) external returns (bool);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

struct ContractInfo {
    string name;
    address addr;
}

contract DeployFactory is Script {
    // Get environment variables.
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.envAddress("DEPLOYER");
    bool isMainnet = vm.envBool("DEPLOY_FLAG_MAINNET"); 

    // Constants
    address WBNB_bsc_mainnet = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address uniswapFactory_bsc_mainnet = 0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7;
    address pancakeSwapFactory__bsc_mainnet = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;

    address WBNB_bsc_testnet = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address uniswapFactory_bsc_testnet = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
    address pancakeSwapFactory__bsc_testnet = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
    address WBNB = isMainnet ? WBNB_bsc_mainnet : WBNB_bsc_testnet;

    // uniswapV3Factory: "0x961235a9020B05C44DF1026D956D1F4D78014276",
    // pancakeV3Factory: "0x3b7838D96Fc18AD1972aFa17574686be79C50040",
    // pancakeQuoterV2: "0x7f988126C2c5d4967Bb5E70bDeB7e26DB6BD5C28",
    // uniswapQuoterV2: "0x1b4E313fEF15630AF3e6F2dE550Dbf4cC9D3081d",
    // WBNB: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",

    ContractInfo[] private expectedAddressesInResolver;

    OikosFactory private nomaFactory;
    Resolver private resolver;
    OikosDividends private dividendDistributor;

    function run() public {  

        vm.startBroadcast(privateKey);

        expectedAddressesInResolver.push(
            ContractInfo("WBNB", WBNB)
        );
        
        // Resolver
        resolver = new Resolver(deployer);

        expectedAddressesInResolver.push(
            ContractInfo("Resolver", address(resolver))
        );  

        console.log("Resolver address: ", address(resolver));

        
        // Presale Factory
        PresaleFactory presaleFactory = new PresaleFactory(address(resolver));

        expectedAddressesInResolver.push(
            ContractInfo("PresaleFactory", address(presaleFactory))
        );

        DeployerFactory deploymentFactory = new DeployerFactory(address(resolver));
        ExtFactory extFactory = new ExtFactory(address(resolver));

        // Oikos Factory
        nomaFactory = new OikosFactory(
            isMainnet ? uniswapFactory_bsc_mainnet : uniswapFactory_bsc_testnet,
            isMainnet ? pancakeSwapFactory__bsc_mainnet : pancakeSwapFactory__bsc_testnet,
            address(resolver),
            address(deploymentFactory),
            address(extFactory),
            address(presaleFactory)
        );
        
        expectedAddressesInResolver.push(
            ContractInfo("OikosFactory", address(nomaFactory))
        );

        ProtocolParameters memory _params =
        ProtocolParameters(
            10,             // Floor percentage of total supply
            5,              // Anchor percentage of total supply
            3,              // IDO price multiplier
            [200, 500],     // Floor bips
            90e16,          // Shift liquidity ratio
            115e16,         // Slide liquidity ratio
            15000,          // Discovery deploy bips
            10,             // shiftAnchorUpperBips
            300,            // slideAnchorUpperBips
            5,              // lowBalanceThresholdFactor
            2,              // highBalanceThresholdFactor
            5,              // inflationFee
            25,             // maxLoanUtilization
            27,             // loan interest fee
            0.1e18,         // deployFee (ETH)
            25,             // presalePremium (25%)
            1_250,          // selfRepayLtvTreshold
            0.5e18,         // Adaptive supply curve half step
            2,              // Skim ratio
            Decimals(6, 18),// min and max decimals
            1e14,           // basePriceDecimals
            5,              // reservedBalanceThreshold (%)
            // MEV Protection
            120,            // twapPeriod (2 minutes - works with cardinality ~50 on BSC)
            200             // maxTwapDeviation (200 ticks ~2%)
        );

        PresaleProtocolParams memory _presaleParams =
        PresaleProtocolParams(
            60,         // Max soft cap (60%)
            10,         // Min contribution ratio BPS 0.10%
            800,        // Max contribution ratio BPS 8.00%
            20,         // Percentage of funds kept from presale (20%)
            30 days,    // Min deadline
            180 days,   // Max deadline
            3,          // Referral bonus (3%)
            5           // Team fee (5%)
        );

        nomaFactory.setProtocolParameters(_params);
        nomaFactory.setPresaleProtocolParams(_presaleParams);

        resolver.initFactory(address(nomaFactory));

        configureResolver();

        console.log("Factory deployed to address: ", address(nomaFactory));

        vm.stopBroadcast();
    }

    function configureResolver() internal {
        bytes32[] memory names = new bytes32[](expectedAddressesInResolver.length);
        address[] memory addresses = new address[](expectedAddressesInResolver.length);

        for (uint256 i = 0; i < expectedAddressesInResolver.length; i++) {
            names[i] = Utils.stringToBytes32(expectedAddressesInResolver[i].name);
            addresses[i] = expectedAddressesInResolver[i].addr;
        }

        bool areAddressesInResolver = resolver.areAddressesImported(names, addresses);

        if (!areAddressesInResolver) {
            resolver.importAddresses(names, addresses);
        }

        areAddressesInResolver = resolver.areAddressesImported(names, addresses);
        console.log("Addresses are imported in resolver: %s", areAddressesInResolver);
        
    }    

}   
