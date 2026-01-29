// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { VaultStorage } from "../libraries/LibAppStorage.sol";
import "../errors/Errors.sol";

interface ILendingVault {
    function borrowFromFloor(address who, uint256 borrowAmount, uint256 duration) external;
    function paybackLoan(address who, uint256 amount, bool isSelfRepaying) external;
    function rollLoan(address who, uint256 newDuration) external returns (uint256 amount);
    function addCollateral(address who, uint256 amount) external;
    function vaultSelfRepayLoans(uint256 fundsToPull, uint256 start, uint256 limit) external returns (uint256 totalLoans, uint256 collateralToReturn);
    function migrateLoan(address vault, address who) external;
}

// Events
event Borrow(address indexed who, uint256 borrowAmount, uint256 duration);
event Payback(address indexed who, uint256 amount);
event RollLoan(address indexed who, uint256 amount, uint256 newDuration);
event SelfRepayLoans(uint256 totalLoans, uint256 collateralReturned);

/**
 * @title ExtVaultLending
 * @notice Facet for lending operations (borrow, payback, roll, collateral).
 * @dev Split from ExtVault to reduce contract size below 24KB limit.
 *      This facet contains thin wrappers that forward to ILendingVault.
 */
contract ExtVaultLending {
    VaultStorage internal _v;

    /**
     * @notice Allows a user to borrow tokens from the vault's floor liquidity.
     * @param borrowAmount The amount of tokens to borrow.
     * @param duration The duration of the loan.
     */
    function borrow(
        uint256 borrowAmount,
        uint256 duration
    ) public {

        ILendingVault(address(this))
        .borrowFromFloor(
            msg.sender,
            borrowAmount,
            duration
        );

        emit Borrow(msg.sender, borrowAmount, duration);
    }

    /**
     * @notice Allows a user to pay back a loan.
     * @param amount The amount to repay.
     */
    function payback(uint256 amount) public {

        ILendingVault(address(this))
        .paybackLoan(msg.sender, amount, false);

        emit Payback(msg.sender, amount);
    }

    /**
     * @notice Allows a user to roll over a loan.
     * @param newDuration The new duration for the rolled loan.
     */
    function roll(
        uint256 newDuration
    ) public {

        uint256 amount =
        ILendingVault(address(this))
        .rollLoan(
            msg.sender,
            newDuration
        );

        emit RollLoan(msg.sender, amount, newDuration);
    }

    /**
     * @notice Allows a user to add collateral to their loan.
     * @param amount The amount of collateral to add.
     */
    function addCollateral(
        uint256 amount
    ) public {

        ILendingVault(address(this))
        .addCollateral(msg.sender, amount);
    }

    /**
     * @notice Allows the vault to self-repay loans using available funds.
     * @param fundsToPull The amount of funds to use for repayment.
     * @param start The starting index for loan iteration.
     * @param limit The maximum number of loans to process.
     */
    function selfRepayLoans(
        uint256 fundsToPull,
        uint256 start,
        uint256 limit
    ) public {
        (uint256 totalLoans, uint256 collateralToReturn) =
        ILendingVault(address(this))
        .vaultSelfRepayLoans(fundsToPull, start, limit);

        emit SelfRepayLoans(totalLoans, collateralToReturn);
    }

    function migrateLoan(address vault) public {
        ILendingVault(address(this))
        .migrateLoan(vault, msg.sender);
    }

    /**
     * @notice Retrieves the function selectors for this contract.
     * @return selectors An array of function selectors.
     */
    function getFunctionSelectors() external pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = bytes4(keccak256(bytes("borrow(uint256,uint256)")));
        selectors[1] = bytes4(keccak256(bytes("payback(uint256)")));
        selectors[2] = bytes4(keccak256(bytes("roll(uint256)")));
        selectors[3] = bytes4(keccak256(bytes("addCollateral(uint256)")));
        selectors[4] = bytes4(keccak256(bytes("selfRepayLoans(uint256,uint256,uint256)")));
        selectors[5] = bytes4(keccak256(bytes("migrateLoan(address)")));
        return selectors;
    }
}
