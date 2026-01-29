// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//  ██████╗ ██╗██╗  ██╗ ██████╗ ███████╗
// ██╔═══██╗██║██║ ██╔╝██╔═══██╗██╔════╝
// ██║   ██║██║█████╔╝ ██║   ██║███████╗
// ██║   ██║██║██╔═██╗ ██║   ██║╚════██║
// ╚██████╔╝██║██║  ██╗╚██████╔╝███████║
//  ╚═════╝ ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝                                 
//
// Centralized Error Definitions
// All custom errors for the Oikos Protocol

/// @notice Centralized error definitions to avoid duplication across contracts

// ============ Access Control Errors ============
error Unauthorized();
error NotAuthorized();
error OnlyFactory();
error OnlyDeployer();
error OnlyVault();
error OnlyOwner();
error OnlyInternalCalls();
error NotPermitted();

// ============ Initialization Errors ============
error AlreadyInitialized();
error NotInitialized();
error ResolverNotSet();
error InvalidResolver();

// ============ Address Errors ============
error ZeroAddress();
error InvalidAddress();

// ============ Validation Errors ============
error InvalidAmount();
error InvalidParams();
error InvalidPosition();
error InvalidDuration();
error InvalidSymbol();
error InvalidStep();

// ============ Liquidity Errors ============
error NoLiquidity();
error ZeroLiquidity();
error InvalidBalance();
error InsufficientBalance();
error InvalidTick();
error InvalidTicksFloor();
error InvalidTicksAnchor();
error InvalidTicksDiscovery();
error InvalidFloor();
error PositionsLength();
error OnlyNotEmptyPositions();
error ZeroAnchorBalance();
error InvalidThresholds();

// ============ Threshold Errors ============
error AboveThreshold();
error BelowThreshold();

// ============ Lending Errors ============
error InsufficientLoanAmount();
error InsufficientFloorBalance();
error InsufficientCollateral();
error NoActiveLoan();
error ActiveLoan();
error LoanExpired();
error CantRollLoan();
error InvalidRepayAmount();
error noExistingVault();

// ============ Token Errors ============
error InvalidTransfer();
error NonTransferrable();
error CannotRecoverSelfToken();
error CannotRecoverTokens();
error MinimumSupplyReached();
error TokenAlreadyExistsError();
error SupplyTransferError();
error MintAmount();
error BalanceToken0();
error NothingToMint();
error ZeroAmount();
error InvalidRate();
error InsufficientTokenOut();

// ============ Swap/Exchange Errors ============
error NoTokensExchanged();
error InvalidSwap();
error SlippageExceeded();
error PriceImpactTooHigh();
error ShiftPriceDeviationExceeded(uint256 priceBefore, uint256 priceAfter, uint256 maxDeviation);

// ============ MEV Protection Errors ============
/// @notice Thrown when spot price deviates too much from TWAP (potential manipulation)
error TwapDeviationExceeded(uint256 spotPrice, uint256 twapPrice, uint256 maxDeviation);
/// @notice Thrown when shift() is called too soon after previous shift
error ShiftRateLimited(uint256 lastShift, uint256 minInterval);
/// @notice Thrown when unauthorized address tries to call shift()
error ShiftAccessDenied(address caller);
/// @notice Thrown when TWAP observation fails (not enough history)
error TwapObservationFailed();

error Manipulated();

// ============ Staking Errors ============
error StakingContractNotSet();
error NoStakingRewards();
error StakingNotEnabled();
error NotEnoughBalance(uint256 currentBalance);
error InvalidReward();
error CooldownNotElapsed();
error LockInPeriodNotElapsed();

// ============ Dividends Errors ============
error InvalidRewardToken();
error NoShares();
error NotSharesToken();

// ============ Callback Errors ============
error CallbackCaller();
error ReentrantCall();

// ============ Vault Errors ============
error LiquidityOpRequired();
error UpgradeFailed();
error InsolvencyInvariant();
error Unused();

// ============ Factory Errors ============
error InvalidTokenAddressError();
error PredictionNotFoundWithinLimit();
error TransferFailed();

// ============ Migration Errors ============
error InvalidHelper();
error InvalidToken();
error InvalidVault();
error IMVMustBeGreaterThanZero();
error DurationMustBeGreaterThanZero();
error HoldersBalancesMismatchOrEmpty();
error MigrationEnded();
error NoBalanceSet();
error IMVNotGrown();
error NothingToWithdraw();
error MismatchOrEmpty();
error NoTokens();
error NoExcessTokens();
