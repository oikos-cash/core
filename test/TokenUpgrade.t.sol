// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import "./token/TestMockOikosToken.sol";
import "./token/TestMockOikosTokenV2.sol";
import "openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

struct ContractAddressesJson {
    address Factory;
    address IDOHelper;
    address ModelHelper;
    address Proxy;
}

interface IOikosFactory {
    function upgradeToken(
        address _token,
        address _newImplementation
    ) external;
    function owner() external view returns (address);
}

interface IOikosTokenOwnable {
    function owner() external view returns (address);
}

contract TestTokenUpgrade is Test {
    using stdJson for string;

    TestMockOikosToken public mockOikosToken;
    TestMockOikosTokenV2 public mockOikosTokenV2;
    ERC1967Proxy public proxy;

    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.envAddress("DEPLOYER");

    address user = address(2);
    address uniswapV3Pool = 0x18255e6a727Ed2f9c7261E8A59Fb6F884CB6C368;
    address nonUniswapV3Pool = address(4);
    address factoryAddress = address(0);
    address proxyAddress = address(0);
    address factoryAuthority;
    address tokenOwner;

    function setUp() public {
        // Define the file path
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deploy_helper/out/out.json");

        // Read the JSON file
        string memory json = vm.readFile(path);
        string memory networkId = "1337";

        // Parse individual fields to avoid struct ordering issues
        factoryAddress = vm.parseJsonAddress(json, string.concat(".", networkId, ".Factory"));
        proxyAddress = vm.parseJsonAddress(json, string.concat(".", networkId, ".Proxy"));

        // Get factory authority
        factoryAuthority = IOikosFactory(factoryAddress).owner();

        // Get actual token owner (who deployed the vault, not the factory)
        tokenOwner = IOikosTokenOwnable(proxyAddress).owner();

        console.log("Factory Address:", factoryAddress);
        console.log("Proxy Address:", proxyAddress);
        console.log("Factory Authority:", factoryAuthority);
        console.log("Token Owner:", tokenOwner);
    }

    function testDirectUpgrade() public {
        // Deploy new implementation
        mockOikosTokenV2 = new TestMockOikosTokenV2();

        // Upgrade the proxy to use the new implementation
        // The token owner is whoever deployed the vault (msg.sender during deployVault)
        vm.prank(tokenOwner);
        TestMockOikosToken(proxyAddress).upgradeToAndCall(address(mockOikosTokenV2), new bytes(0));

        // Cast the proxy to MockOikosTokenV2 to interact with the new implementation
        TestMockOikosTokenV2 upgraded = TestMockOikosTokenV2(proxyAddress);

        // Check if the new implementation is in use
        assertEq(upgraded.version(), "V2");
    }

    function testUpgradeThroughFactory() public {
        // Deploy new implementation
        mockOikosTokenV2 = new TestMockOikosTokenV2();

        // The factory's upgradeToken() calls token.upgradeToAndCall(), which requires
        // the factory to be the token owner. First transfer ownership to factory.
        vm.prank(tokenOwner);
        TestMockOikosToken(proxyAddress).setOwner(factoryAddress);

        // Verify factory now owns the token
        assertEq(IOikosTokenOwnable(proxyAddress).owner(), factoryAddress, "Factory should own token");

        // Upgrade the proxy through the factory using the factory authority
        vm.prank(factoryAuthority);
        IOikosFactory(factoryAddress).upgradeToken(proxyAddress, address(mockOikosTokenV2));

        // Cast the proxy to MockOikosTokenV2 to interact with the new implementation
        TestMockOikosTokenV2 upgraded = TestMockOikosTokenV2(proxyAddress);

        // Check if the new implementation is in use
        assertEq(upgraded.version(), "V2");
    }

    function testCannotUpgradeFromNonAuthority() public {
        // Deploy new implementation
        mockOikosTokenV2 = new TestMockOikosTokenV2();

        // Try to upgrade the proxy from a non-authority account
        vm.prank(user);
        vm.expectRevert();
        IOikosFactory(factoryAddress).upgradeToken(proxyAddress, address(mockOikosTokenV2));

        // Verify that the upgrade did not happen by checking the version is still V1
        assertEq(TestMockOikosToken(proxyAddress).version(), "1");
    }

    function testCannotDirectUpgradeFromNonOwner() public {
        // Deploy new implementation
        mockOikosTokenV2 = new TestMockOikosTokenV2();

        // Try to upgrade directly from non-owner - should fail
        vm.prank(user);
        vm.expectRevert();
        TestMockOikosToken(proxyAddress).upgradeToAndCall(address(mockOikosTokenV2), new bytes(0));

        // Verify version unchanged
        assertEq(TestMockOikosToken(proxyAddress).version(), "1");
    }
}