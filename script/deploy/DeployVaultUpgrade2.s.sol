// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Resolver } from "../../src/Resolver.sol";
import { VaultDeployParams, VaultDescription, ProtocolParameters, PresaleProtocolParams } from "../../src/types/Types.sol";
import { 
    VaultUpgrade, 
    VaultUpgradeStep1, 
    VaultUpgradeStep2,
    VaultUpgradeStep3,
    VaultUpgradeStep4,
    VaultUpgradeStep5
} from "../../src/vault/init/VaultUpgrade.sol";
import { 
    VaultInit
} from "../../src/vault/init/VaultInit.sol";
import { Utils } from "../../src/libraries/Utils.sol";

struct ContractInfo {
    string name;
    address addr;
}

struct ContractAddressesJson {
    address Factory;
    address ModelHelper;
    address Resolver;
}

contract DeployVaultUpgrade2 is Script {
    using stdJson for string;

    // Get environment variables.
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.envAddress("DEPLOYER");
    bool isMainnet = vm.envBool("DEPLOY_FLAG_MAINNET"); 
    bool isChainFork = vm.envBool("DEPLOY_FLAG_FORK");     

    ContractInfo[] private expectedAddressesInResolver;
    Resolver private resolver;

    // Constants
    address WBNB_bsc_mainnet = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address uniswapFactory_bsc_mainnet = 0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7;
    address pancakeSwapFactory__bsc_mainnet = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;

    address WBNB_bsc_testnet = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address uniswapFactory_bsc_testnet = 0x961235a9020B05C44DF1026D956D1F4D78014276;
    address pancakeSwapFactory__bsc_testnet = 0x3b7838D96Fc18AD1972aFa17574686be79C50040;
    address WBNB = isMainnet ? WBNB_bsc_mainnet : WBNB_bsc_testnet;

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
        console2.log("Factory Address:", addresses.Factory);

        resolver = Resolver(addresses.Resolver);

        VaultUpgradeStep3 vaultUpgradeStep3 = new VaultUpgradeStep3(deployer, address(addresses.Factory));
        VaultUpgradeStep4 vaultUpgradeStep4 = new VaultUpgradeStep4(deployer, address(addresses.Factory));
        VaultUpgradeStep5 vaultUpgradeStep5 = new VaultUpgradeStep5(deployer, address(addresses.Factory));

        expectedAddressesInResolver.push(
            ContractInfo("VaultUpgradeStep3", address(vaultUpgradeStep3))
        );

        expectedAddressesInResolver.push(
            ContractInfo("VaultUpgradeStep4", address(vaultUpgradeStep4))
        );

        expectedAddressesInResolver.push(
            ContractInfo("VaultUpgradeStep5", address(vaultUpgradeStep5))
        );

        // Configure resolver
        configureResolver();

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