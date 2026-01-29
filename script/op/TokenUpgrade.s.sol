// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "../../src/token/OikosToken.sol";
import "../../src/token/OikosTokenV2.sol";
import "../../src/token/OikosTokenV3.sol";
import "../../src/token/OikosTokenV4.sol";
import "../../src/token/OikosTokenV5.sol";

interface IOikosFactory {
    function upgradeToken(address _token, address _newImplementation) external;
    function owner() external view returns (address);
}

interface IToken {
    function version() external view returns (string memory);
    function owner() external view returns (address);
    function manager() external view returns (address);
    function resolver() external view returns (address);
}

interface IUpgradeable {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

interface ITokenOwnable {
    function setOwner(address _owner) external;
}

contract TokenUpgrade is Script {
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.envAddress("DEPLOYER");

    // Mainnet addresses
    address public constant TOKEN_PROXY = 0x614da16Af43A8Ad0b9F419Ab78d14D163DEa6488;
    address public constant FACTORY = 0x7Ca7553228025caf169DBd02e44c0ccE637de80B;

    // Old factory that may own the token
    address public constant OLD_FACTORY = 0xCfbfa73cA0993b971d46447B3056BD8557dFC3e1;

    function run() public {
        upgrade(5); // Default to latest version
    }

    function upgrade(uint256 targetVersion) public {
        IToken token = IToken(TOKEN_PROXY);
        string memory currentVersionStr = token.version();
        uint256 currentVersion = parseVersion(currentVersionStr);
        address tokenOwner = token.owner();

        console.log("=== Token Upgrade ===");
        console.log("Token proxy:", TOKEN_PROXY);
        console.log("Current version:", currentVersionStr);
        console.log("Target version:", targetVersion);
        console.log("Token owner:", tokenOwner);
        console.log("Token manager:", token.manager());
        console.log("Deployer:", deployer);

        if (currentVersion >= targetVersion) {
            console.log("Already at or above target version. Nothing to do.");
            return;
        }

        // Check ownership - must be deployer (use token_upgrade.sh for Anvil fork)
        require(tokenOwner == deployer, "Deployer must own token. Run token_upgrade.sh for Anvil fork.");

        vm.startBroadcast(privateKey);

        // Deploy new implementation based on target version
        address newImpl = deployImplementation(targetVersion);
        console.log("New implementation deployed:", newImpl);

        // Upgrade token
        upgradeToken(newImpl, targetVersion);

        // Verify
        string memory newVersionStr = token.version();
        console.log("Upgrade complete! New version:", newVersionStr);

        vm.stopBroadcast();
    }

    function deployImplementation(uint256 version) internal returns (address) {
        if (version == 1) {
            return address(new OikosToken());
        } else if (version == 2) {
            return address(new OikosTokenV2());
        } else if (version == 3) {
            return address(new OikosTokenV3());
        } else if (version == 4) {
            return address(new OikosTokenV4());
        } else if (version == 5) {
            return address(new OikosTokenV5());
        } else {
            revert("Unknown version");
        }
    }

    function upgradeToken(address newImpl, uint256 targetVersion) internal {
        // Build initialization calldata based on target version
        bytes memory initData;

        if (targetVersion == 2) {
            // V2 needs manager address
            initData = abi.encodeWithSignature("initializeV2(address)", deployer);
        } else if (targetVersion == 3) {
            initData = abi.encodeWithSignature("initializeV3()");
        } else if (targetVersion == 4) {
            initData = abi.encodeWithSignature("initializeV4()");
        } else if (targetVersion == 5) {
            initData = abi.encodeWithSignature("initializeV5()");
        }

        // Check if deployer is the token owner - if so, upgrade directly
        address tokenOwner = IToken(TOKEN_PROXY).owner();
        if (deployer == tokenOwner) {
            console.log("Upgrading directly (deployer is token owner)...");
            IUpgradeable(TOKEN_PROXY).upgradeToAndCall(newImpl, initData);
        } else {
            // Try factory upgrade if deployer owns the factory
            address factoryOwner = IOikosFactory(FACTORY).owner();
            require(deployer == factoryOwner, "Not authorized to upgrade");

            console.log("Upgrading through factory...");
            IOikosFactory(FACTORY).upgradeToken(TOKEN_PROXY, newImpl);

            // Call initializer if needed
            if (initData.length > 0) {
                console.log("Calling initializer...");
                (bool success,) = TOKEN_PROXY.call(initData);
                require(success, "Initializer failed");
            }
        }
    }

    function parseVersion(string memory v) internal pure returns (uint256) {
        bytes memory b = bytes(v);
        if (b.length == 0) return 0;
        // Simple single digit version parsing
        return uint256(uint8(b[0]) - 48);
    }
}
