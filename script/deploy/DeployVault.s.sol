// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import { OikosFactory } from  "../../src/factory/OikosFactory.sol";
import { 
    ProtocolAddresses,
    VaultDeployParams, 
    PresaleUserParams, 
    VaultDescription, 
    ProtocolParameters,
    ExistingDeployData,
    LiquidityPosition,
    LiquidityType
} from "../../src/types/Types.sol";
import { IDOHelper } from "../../test/IDO_Helper/IDOHelper.sol";
import { BaseVault } from  "../../src/vault/BaseVault.sol";
import { Migration } from "../../src/bootstrap/Migration.sol";
import {IUniswapV3Pool} from "v3-core/interfaces/IUniswapV3Pool.sol";

struct ContractAddressesJson {
    address Factory;
    address ModelHelper;
}

interface IPresaleContract {
    function setMigrationContract(address _migrationContract) external ;

}

interface IERC20 {
    function balanceOf(address who) external returns (uint256);
    function transfer(address who, uint256 amount) external;
}

interface IVault {
    function setLiquidity(
        LiquidityPosition[3] memory positions,
        uint256 amount1Floor,
        uint256 amount1Anchor
    ) external;
}

interface IWBNB {
    function deposit() external payable;
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DeployVault is Script {
    using stdJson for string;

    // Get environment variables.
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.envAddress("DEPLOYER");
    bool isMainnet = vm.envBool("DEPLOY_FLAG_MAINNET"); 
    bool isChainFork = vm.envBool("DEPLOY_FLAG_FORK"); 
    bool deployTests = vm.envBool("DEPLOY_TEST"); 

    // Constants
    address WBNB_bsc_mainnet = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address WBNB_bsc_testnet = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address WBNB = isMainnet ? WBNB_bsc_mainnet : WBNB_bsc_testnet;

    address constant POOL = 0x104bab30b2983df47dd504114353B0A73bF663CE;
    address constant OKS = 0x614da16Af43A8Ad0b9F419Ab78d14D163DEa6488;
    address constant VAULT1 = 0x10229DC66ac45b6Ecd2c71ca480EDD013dE701aD;
    address constant VAULT2 = 0x5EffFAD2602DCe520C09c58fa88b0e06609C52b8;
    address constant VAULT3 = 0x1E9AEF03ccD42c9531e404939f45d3A4e922ED9D;

    address private nomaFactoryAddress;
    address private modelHelper;

    IDOHelper private idoManager;

    function run() public {  
        vm.startBroadcast(privateKey);

        // Define the file path
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deploy_helper/out/out_dummy.json");

        // Read the JSON file
        string memory json = vm.readFile(path);
        string memory networkId = isChainFork ? "1337" : isMainnet ? "56" : "10143"; 

        // Parse the data for network ID 
        bytes memory data = vm.parseJson(json, string.concat(string("."), networkId));

        // Decode the data into the ContractAddresses struct
        ContractAddressesJson memory addresses = abi.decode(data, (ContractAddressesJson));
        
        // Log parsed addresses for verification
        console2.log("Model Helper Address:", addresses.ModelHelper);
        console2.log("Factory Address:", addresses.Factory);

        // Extract addresses from JSON
        modelHelper = addresses.ModelHelper;
        nomaFactoryAddress = addresses.Factory;

        OikosFactory nomaFactory = OikosFactory(nomaFactoryAddress);

        bool useUniswap = true;
        bool isFreshDeploy = true;

        VaultDeployParams memory vaultDeployParams = 
        VaultDeployParams(
            "OKS TOKEN",
            "OKS",
            18,
            14000000000000000000000000,
            1400000000000000000000000000,
            25000000000000000,
            1,
            WBNB,
            useUniswap ? 3000 : 2500,   
            0,                          // 0 = no presale
            isFreshDeploy,              // isFreshDeploy
            useUniswap                  // useUniswap 
        );

        PresaleUserParams memory presaleParams =
        PresaleUserParams(
            3000000000000000000000,     // softCap
            86400 * 30                  // duration (seconds)
        );

        (address vault, address pool, address proxy) = 
        nomaFactory
        .deployVault(
            presaleParams,
            vaultDeployParams,
            ExistingDeployData({
                pool: address(0),
                token0: address(0),
                vaultAddress: address(0)
            })            
        );
        
//        nomaFactory.configureVault(vault, 0);
        // IUniswapV3Pool(pool).increaseObservationCardinalityNext(50);

        // console.log("Wrapping BNB to WBNB...");
        // IWBNB(WBNB).deposit{value: 27244084326000000000}();

        uint256 balanceOks = IERC20(OKS).balanceOf(deployer);
        uint256 balanceWbnb = IERC20(WBNB).balanceOf(deployer);

        console.log("Balance WBNB is ", balanceWbnb);

        // IERC20(OKS).transfer(vault, balanceOks / 64);
        // IERC20(WBNB).transfer(vault, 27264084326000000000);
        // setLiquidity(vault);

        if (deployTests) {
            // nomaFactory.configureVault(vault, 0);

            idoManager = new IDOHelper(pool, vault, modelHelper, proxy, WBNB);
            console.log("IDOHelper address: ", address(idoManager));
        }

        console.log("Vault address: ", vault);
        console.log("Pool address: ", pool);
        console.log("Proxy address: ", proxy);
    }


    function setLiquidity(address vault) internal {
        IVault(vault).setLiquidity(
            [
                LiquidityPosition({                                                                                                                                        
                    lowerTick: -91920,                                                                                                                                     
                    upperTick: -91860,                                                                                                                               
                    liquidity: 1,                                                                                                                                          
                    price: 0,                                                                                                                                              
                    tickSpacing: 60,                                                                                                                                       
                    liquidityType: LiquidityType.Floor                                                                                                                     
                }),                                                                                                                                                        
                LiquidityPosition({                                                                                                                                        
                    lowerTick: -91800,                                                                                                                                     
                    upperTick: -83220,                                                                                                                                
                    liquidity: 1,                                                                                                                                          
                    price: 0,                                                                                                                                              
                    tickSpacing: 60,                                                                                                                                       
                    liquidityType: LiquidityType.Anchor                                                                                                                    
                }),                                                                                                                                                        
                LiquidityPosition({                                                                                                                                        
                    lowerTick: -83160,                                                                                                                                     
                    upperTick: -82200,                                                                                                                                                     
                    liquidity: 1,                                                                                                                                          
                    price: 0,                                                                                                                                              
                    tickSpacing: 60,                                                                                                                                       
                    liquidityType: LiquidityType.Discovery                                                                                                                 
                })                                                                                                                                                      
                // LiquidityPosition({
                //     lowerTick: -91860,                                                                                                                                     
                //     upperTick: -91800,                                                                                                                                     
                //     liquidity: 1,                                                                                                                   
                //     price: 0,                                                                                                                                              
                //     tickSpacing: 60,                                                                                                                                       
                //     liquidityType: LiquidityType.Floor    
                // }),
                // LiquidityPosition({
                //     lowerTick: -91740,                                                                                                                                    
                //     upperTick: -83160,                                                                                                                                     
                //     liquidity: 1,                                                                                                                   
                //     price: 0,                                                                                                                                              
                //     tickSpacing: 60,                                                                                                                                       
                //     liquidityType: LiquidityType.Floor    
                // }),
                // LiquidityPosition({
                //     lowerTick: -83100,                                                                                                                                     
                //     upperTick: -80880,   // ~3x floor price  
                //     liquidity: 1,
                //     price: 0,
                //     tickSpacing: 60,
                //     liquidityType: LiquidityType.Discovery
                // })                                        
            ],
            27144084326000000000, // 12.9839  amount1Floor
            0.1e18 // 27.4977 amount1Anchor
        );
    }

}