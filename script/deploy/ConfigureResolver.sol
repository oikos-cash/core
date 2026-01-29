

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import { Utils } from "../../src/libraries/Utils.sol";
import { Resolver } from "../../src/Resolver.sol";
import { OikosDividends } from "../../src/controllers/OikosDividends.sol";

struct ContractInfo {
    string name;
    address addr;
}

interface IOikosToken {
    function setDividendsManager(OikosDividends _manager) external;
    function owner() external view returns (address);
}

contract ConfigureResolver is Script {
    // Get environment variables.
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.envAddress("DEPLOYER");
    bool isMainnet = vm.envBool("DEPLOY_FLAG_MAINNET"); 
    bool isChainFork = vm.envBool("DEPLOY_FLAG_FORK");     

    ContractInfo[] private expectedAddressesInResolver;

    Resolver private resolver;
    OikosDividends private nomaDividends;

    address private resolverAddress = 0x91377381456865e474a33FF157444f26B0645fD4;
    address private nomaTokenAddress = 0x614da16Af43A8Ad0b9F419Ab78d14D163DEa6488;
    address private nomaFactoryAddress = 0x525E38Ae23716e169086E6B8b474AB054E3734c9;

    function run() public {  
        vm.startBroadcast(privateKey);

        resolver = Resolver(resolverAddress);
        
        nomaDividends = new OikosDividends(nomaFactoryAddress, resolverAddress);

        expectedAddressesInResolver.push(
            ContractInfo("DividendDistributor", address(nomaDividends))
        );
        
        console.log("DividendDistributor deployed to address: ", address(nomaDividends));

        expectedAddressesInResolver.push(
            ContractInfo("OikosToken", nomaTokenAddress)
        );

        // Configure resolver
        configureResolver();

        nomaDividends.setSharesToken{gas: 1000000}();

        address contractOwner = IOikosToken(nomaTokenAddress).owner();
        console.log("Contract owner is ", contractOwner);

        IOikosToken(nomaTokenAddress).setDividendsManager{gas: 3000000}(nomaDividends);

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