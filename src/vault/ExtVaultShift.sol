// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    LiquidityPosition,
    ProtocolAddresses
} from "../types/Types.sol";

import { IVault } from "../interfaces/IVault.sol";
import { VaultStorage } from "../libraries/LibAppStorage.sol";
import { LiquidityOps } from "../libraries/LiquidityOps.sol";
import "../errors/Errors.sol";

interface IStakingVault {
    function mintAndDistributeRewards(address caller, ProtocolAddresses memory addresses) external;
}

// Events
event Shift();
event Slide();

/**
 * @title ExtVaultShift
 * @notice Facet for shift and slide liquidity operations.
 * @dev Split from ExtVault to reduce contract size below 24KB limit.
 *      This facet contains the heavy LiquidityOps library usage.
 */
contract ExtVaultShift {
    VaultStorage internal _v;

    /**
     * @notice Shifts the liquidity positions in the vault.
     * @dev This function adjusts the liquidity positions and distributes staking rewards.
     * @dev It also pays rewards to the caller.
     */
    function shift() public {

        LiquidityPosition[3] memory positions =
        IVault(address(this))
        .getPositions();

        ProtocolAddresses memory addresses =
        IVault(address(this))
        .getProtocolAddresses();

        LiquidityOps.shift(
            addresses,
            positions
        );

        if (_v.isStakingSetup) {
            IStakingVault(address(this))
            .mintAndDistributeRewards(msg.sender, addresses);
        }

        emit Shift();
    }

    /**
     * @notice Slides the liquidity positions in the vault.
     * @dev This function adjusts the liquidity positions without distributing staking rewards.
     */
    function slide() public {

        LiquidityPosition[3] memory positions =
        IVault(address(this))
        .getPositions();

        ProtocolAddresses memory addresses =
        IVault(address(this))
        .getProtocolAddresses();

        LiquidityOps.slide(
            addresses,
            positions
        );

        emit Slide();
    }

    /**
     * @notice Retrieves the function selectors for this contract.
     * @return selectors An array of function selectors.
     */
    function getFunctionSelectors() external pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256(bytes("shift()")));
        selectors[1] = bytes4(keccak256(bytes("slide()")));
        return selectors;
    }
}
