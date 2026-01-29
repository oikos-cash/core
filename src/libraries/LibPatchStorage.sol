// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title PatchStorage
 * @notice DEPRECATED for fresh deployments. Only used for upgrading existing vaults.
 *
 * @dev For FRESH DEPLOYMENTS:
 *      - twapPeriod and maxTwapDeviation are now in ProtocolParameters (Types.sol)
 *      - shiftCooldown and lastShiftTime are in VaultStorage (LibAppStorage.sol)
 *      - Use AuxVault.getTwapPeriod(), setTwapPeriod(), etc.
 *
 * @dev For UPGRADING EXISTING VAULTS:
 *      - This storage is still used by MEVProtectionConfig.sol facet
 *      - Uses isolated storage slot to avoid layout conflicts
 *      - Access control features (shiftCallers) remain available here
 */
struct PatchStorage {
    /// @notice DEPRECATED - unused, kept for storage layout compatibility
    uint256 maxShiftPriceDeviation;

    /// @notice DEPRECATED for fresh deploys - now in ProtocolParameters
    /// @dev For upgrades only: TWAP lookback period in seconds
    uint32 twapPeriod;
    /// @notice DEPRECATED for fresh deploys - now in ProtocolParameters
    /// @dev For upgrades only: max deviation from TWAP in ticks
    uint256 maxTwapDeviation;

    /// @notice DEPRECATED - duplicate of VaultStorage.shiftCooldown
    uint256 minShiftInterval;
    /// @notice DEPRECATED - duplicate of VaultStorage.lastShiftTime
    uint256 lastShiftTimestamp;

    /// @notice Access control for shift() - upgrade-only feature
    /// @dev If shiftAccessControlEnabled is true, only addresses in shiftCallers can call shift()
    bool shiftAccessControlEnabled;
    mapping(address => bool) shiftCallers;
}

/**
 * @title LibPatchStorage
 * @notice DEPRECATED for fresh deployments. Only used for upgrading existing vaults.
 * @dev This storage is completely separate from VaultStorage to avoid any storage layout issues
 *      when upgrading existing deployments. For fresh deployments, MEV parameters are in
 *      ProtocolParameters and VaultStorage.
 */
library LibPatchStorage {
    /**
     * @notice Get the patch storage.
     * @return ps The patch storage reference.
     */
    function patchStorage() internal pure returns (PatchStorage storage ps) {
        // Use a unique hash that won't collide with existing storage
        // keccak256("oikos.patch.storage.v1") = 0x...
        assembly {
            ps.slot := 0x8a35acfbc15ff81a39ae7d344fd709f28e8600b4aa8c65c6b64bfe7fe36bd19b
        }
    }
}
