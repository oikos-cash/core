

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IUniswapV3Pool } from "v3-core/interfaces/IUniswapV3Pool.sol";
import { 
    TokenInfo, 
    LiquidityPosition, 
    LoanPosition, 
    ProtocolParameters,
    ReferralEntity
}  from "../types/Types.sol";
import { IAddressResolver } from "../interfaces/IAddressResolver.sol";

/**
 * @notice Storage structure for vault state.
 */
struct VaultStorage {
    // Vault state
    address factory;
    address manager;
    IAddressResolver resolver;
    uint256 startedAt;

    // Setup state
    bool isLendingSetup; // @deprecated - unused, kept for storage layout compatibility
    bool isStakingSetup;
    bool isAdvancedConfEnabled;

    // Loans
    address[] loanAddresses;
    uint256 totalLoans;
    uint256 collateralAmount;
    uint8 loanFee;    
    uint256 totalInterest;
    mapping(address => LoanPosition) loanPositions;
    mapping(address => uint256) totalLoansPerUser;

    // Protocol configuration
    ProtocolParameters protocolParameters;
    bool initialized;
    bool stakingEnabled; 
    address existingVault;
    
    // Protocol addresses
    address deployerContract;
    address modelHelper;
    address stakingContract;
    address presaleContract;
    address proxyAddress; // @deprecated - unused, kept for storage layout compatibility
    address adaptiveSupplyController;
    address tokenRepo;
    address vOKSContract;
    address orchestrator;
    address sToken;

    // Liquidity positions
    LiquidityPosition  floorPosition;
    LiquidityPosition  anchorPosition;
    LiquidityPosition  discoveryPosition;
    
    // Staking rewards
    uint256 totalMinted;
    uint256 timeLastMinted;
    
    // Token information
    TokenInfo tokenInfo;

    // Uniswap pool information
    uint24 feeTier; // @deprecated - unused, kept for storage layout compatibility
    int24 tickSpacing;
    IUniswapV3Pool pool;

    // Uniswap Fees
    uint256 feesAccumulatorToken0;
    uint256 feesAccumulatorToken1;

    // Team & Creator Fees
    uint256 totalTeamFees;
    uint256 totalCreatorFees;

    // Referral information
    mapping(bytes8 => ReferralEntity) referrals;

    // Per vault lock state
    mapping(address => bool) isLocked;

    // Rate limiting for shift/slide operations (MEV protection)
    uint256 lastShiftTime;
    uint256 shiftCooldown; // Minimum seconds between shifts (default: 300 = 5 min)
}


/**
 * @notice Library for accessing storage.
 * @dev Uses EIP-7201 style namespaced storage to prevent collisions.
 *      IMPORTANT: The storage slot identifier MUST NOT be changed after deployment
 *      as it would break all existing vault storage.
 */
library LibAppStorage {
    /// @dev Storage slot computed as: keccak256("oikos.protocol.storage.vault.v1") - 1
    /// Using EIP-7201 pattern for reduced collision risk
    /// WARNING: Changing this value breaks ALL existing vault deployments!
    bytes32 private constant VAULT_STORAGE_SLOT = 0x645a8522529f396704427c958181b8b3c2e3de5bc8cc43cc59de795053c1b1a4;

    /**
     * @notice Get the vault storage.
     * @return vs The vault storage.
     */
    function vaultStorage() internal pure returns (VaultStorage storage vs) {
        bytes32 slot = VAULT_STORAGE_SLOT;
        assembly {
            vs.slot := slot
        }
    }
}
