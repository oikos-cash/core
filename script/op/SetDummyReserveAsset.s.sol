// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import { Utils } from "../../src/libraries/Utils.sol";
import { Resolver } from "../../src/Resolver.sol";
import { WETH9 } from "../../src/token/WETH9.sol";

struct ContractInfo {
    string name;
    address addr;
}

contract DeployFactory is Script {
    // Get environment variables.
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.envAddress("DEPLOYER");


    Resolver public resolver;
    ContractInfo[] private expectedAddressesInResolver;

    function run() public {  

        vm.startBroadcast(privateKey);

        resolver = Resolver(0x91377381456865e474a33FF157444f26B0645fD4); // Replace with actual resolver address

        WETH9 weth = new WETH9(deployer);

        expectedAddressesInResolver.push(
            ContractInfo("OikosFactory", address(0x525E38Ae23716e169086E6B8b474AB054E3734c9))
        );

        configureResolver();

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