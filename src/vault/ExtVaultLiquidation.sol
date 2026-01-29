// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { VaultStorage } from "../libraries/LibAppStorage.sol";
import "../errors/Errors.sol";

interface ILiquidationVault {
    function vaultDefaultLoans() external returns (uint256 totalBurned, uint256 loansDefaulted);
    function vaultDefaultLoansRange(uint256 start, uint256 limit) external returns (uint256 totalBurned, uint256 loansDefaulted);
}

// Events
event DefaultLoans(uint256 totalBurned, uint256 loansDefaulted);

/**
 * @title ExtVaultLiquidation
 * @notice Facet for loan liquidation/default operations.
 * @dev Split from ExtVault to reduce contract size below 24KB limit.
 *      This facet contains thin wrappers that forward to ILiquidationVault.
 */
contract ExtVaultLiquidation {
    VaultStorage internal _v;

    /**
     * @notice Allows anybody to default all expired loans.
     * @dev Iterates through all loans and defaults those that are expired.
     */
    function defaultLoans() public {
        (uint256 totalBurned, uint256 loansDefaulted) =
        ILiquidationVault(address(this))
        .vaultDefaultLoans();

        emit DefaultLoans(totalBurned, loansDefaulted);
    }

    /**
     * @notice Allows anybody to default expired loans within a range.
     * @param start The starting index for loan iteration.
     * @param limit The maximum number of loans to process.
     */
    function defaultLoansRange(uint256 start, uint256 limit) public {
        (uint256 totalBurned, uint256 loansDefaulted) =
        ILiquidationVault(address(this))
        .vaultDefaultLoansRange(start, limit);

        emit DefaultLoans(totalBurned, loansDefaulted);
    }

    /**
     * @notice Retrieves the function selectors for this contract.
     * @return selectors An array of function selectors.
     */
    function getFunctionSelectors() external pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256(bytes("defaultLoans()")));
        selectors[1] = bytes4(keccak256(bytes("defaultLoansRange(uint256,uint256)")));
        return selectors;
    }
}
