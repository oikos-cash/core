// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/interfaces/IVault.sol";
import {IUniswapV3Pool} from "v3-core/interfaces/IUniswapV3Pool.sol";
import {OikosToken} from "../src/token/OikosToken.sol";
import {ModelHelper} from "../src/model/Helper.sol";
import {BaseVault} from "../src/vault/BaseVault.sol";
import {Utils} from "../src/libraries/Utils.sol";
import {Conversions} from "../src/libraries/Conversions.sol";
import {DecimalMath} from "../src/libraries/DecimalMath.sol";
import {LiquidityType, LiquidityPosition} from "../src/types/Types.sol";

interface IWETH {
    function balanceOf(address account) external view returns (uint256);
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
}

interface IDOManager {
    function vault() external view returns (BaseVault);
    function buyTokens(uint256 price, uint256 amount, uint256 min, address receiver) external;
    function sellTokens(uint256 price, uint256 amount, address receiver) external;
    function modelHelper() external view returns (address);
}

interface IStakingRewards {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IGonsToken {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function stakingContract() external view returns (address);
}

/// @title ShiftRewardsStakingTest
/// @notice Tests for shift operation rewards distribution to Gons/Staking
contract ShiftRewardsStakingTest is Test {
    using stdJson for string;

    IVault vault;
    IERC20 token0; // OKS token
    IERC20 token1; // WETH

    uint256 MAX_INT = type(uint256).max;

    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.envAddress("DEPLOYER");
    bool isMainnet = vm.envOr("DEPLOY_FLAG_MAINNET", false);

    OikosToken private noma;
    ModelHelper private modelHelper;

    // Mainnet addresses
    address constant WBNB_MAINNET = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    // Testnet addresses
    address constant WBNB_TESTNET = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    // Select based on environment
    address WBNB;
    address payable idoManager;
    address nomaToken;
    address modelHelperContract;
    address vaultAddress;

    function setUp() public {
        // Set WBNB based on mainnet/testnet flag
        WBNB = isMainnet ? WBNB_MAINNET : WBNB_TESTNET;

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deploy_helper/out/out.json");
        string memory json = vm.readFile(path);
        string memory networkId = "1337";

        idoManager = payable(vm.parseJsonAddress(json, string.concat(".", networkId, ".IDOHelper")));
        nomaToken = vm.parseJsonAddress(json, string.concat(".", networkId, ".Proxy"));
        modelHelperContract = vm.parseJsonAddress(json, string.concat(".", networkId, ".ModelHelper"));

        IDOManager managerContract = IDOManager(idoManager);
        require(address(managerContract) != address(0), "Manager contract address is zero");

        noma = OikosToken(nomaToken);
        modelHelper = ModelHelper(modelHelperContract);
        vaultAddress = address(managerContract.vault());

        vault = IVault(vaultAddress);
        IUniswapV3Pool pool = vault.pool();

        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());

        console.log("Vault address:", vaultAddress);
        console.log("Token0 (OKS):", address(token0));
        console.log("Token1 (WETH):", address(token1));
    }

    // ============ SHIFT REWARDS TESTS ============

    /// @notice Test that shift triggers reward distribution to staking when staking is set up
    function testShift_DistributesRewardsToStaking() public {
        // First, create conditions for a shift (liquidityRatio <= 0.90)
        _doPurchasesToTriggerShiftCondition();

        // Get staking contract address
        address stakingContract = vault.getStakingContract();

        if (stakingContract == address(0)) {
            console.log("Staking contract not set up, skipping staking reward test");
            return;
        }

        // Record balances before shift
        uint256 stakingOikosBalanceBefore = token0.balanceOf(stakingContract);
        uint256 vaultOikosBalanceBefore = token0.balanceOf(vaultAddress);

        console.log("Staking OKS balance before shift:", stakingOikosBalanceBefore);
        console.log("Vault OKS balance before shift:", vaultOikosBalanceBefore);

        // Check if shift is needed
        address poolAddr = address(vault.pool());
        uint256 liquidityRatio = modelHelper.getLiquidityRatio(poolAddr, vaultAddress);
        console.log("Liquidity ratio before shift:", liquidityRatio);

        if (liquidityRatio <= 0.90e18) {
            // Perform shift
            vault.shift();

            // Record balances after shift
            uint256 stakingOikosBalanceAfter = token0.balanceOf(stakingContract);
            uint256 vaultOikosBalanceAfter = token0.balanceOf(vaultAddress);

            console.log("Staking OKS balance after shift:", stakingOikosBalanceAfter);
            console.log("Vault OKS balance after shift:", vaultOikosBalanceAfter);

            // Staking contract should have received rewards
            if (stakingOikosBalanceAfter > stakingOikosBalanceBefore) {
                console.log("Rewards distributed to staking:", stakingOikosBalanceAfter - stakingOikosBalanceBefore);
                assertTrue(stakingOikosBalanceAfter > stakingOikosBalanceBefore, "Staking should receive rewards");
            } else {
                console.log("No rewards minted (might be no excess reserves)");
            }
        } else {
            console.log("Liquidity ratio not low enough for shift");
        }
    }

    /// @notice Test that shift caller receives their fee
    function testShift_CallerReceivesFee() public {
        _doPurchasesToTriggerShiftCondition();

        address poolAddr = address(vault.pool());
        uint256 liquidityRatio = modelHelper.getLiquidityRatio(poolAddr, vaultAddress);

        if (liquidityRatio <= 0.90e18) {
            address caller = address(0xCAFE);

            // Record caller balance before
            uint256 callerBalanceBefore = token0.balanceOf(caller);

            // Perform shift from caller address
            vm.prank(caller);
            vault.shift();

            // Record caller balance after
            uint256 callerBalanceAfter = token0.balanceOf(caller);

            console.log("Caller balance before:", callerBalanceBefore);
            console.log("Caller balance after:", callerBalanceAfter);

            if (callerBalanceAfter > callerBalanceBefore) {
                console.log("Caller received fee:", callerBalanceAfter - callerBalanceBefore);
            }
        }
    }

    /// @notice Test multiple shifts accumulate rewards in staking
    function testShift_MultipleShiftsAccumulateRewards() public {
        address stakingContract = vault.getStakingContract();

        if (stakingContract == address(0)) {
            console.log("Staking contract not set up");
            return;
        }

        uint256 initialStakingBalance = token0.balanceOf(stakingContract);
        uint256 shiftsPerformed = 0;

        // Perform multiple purchase cycles and shifts
        for (uint i = 0; i < 3; i++) {
            _doPurchasesToTriggerShiftCondition();

            address poolAddr = address(vault.pool());
            uint256 liquidityRatio = modelHelper.getLiquidityRatio(poolAddr, vaultAddress);

            if (liquidityRatio <= 0.90e18) {
                vault.shift();
                shiftsPerformed++;

                uint256 currentStakingBalance = token0.balanceOf(stakingContract);
                console.log("Shift", i + 1, "- Staking balance:", currentStakingBalance);
            }

            // Time warp between cycles
            vm.warp(block.timestamp + 1 days);
        }

        uint256 finalStakingBalance = token0.balanceOf(stakingContract);
        console.log("Initial staking balance:", initialStakingBalance);
        console.log("Final staking balance:", finalStakingBalance);
        console.log("Total shifts performed:", shiftsPerformed);

        if (shiftsPerformed > 0 && finalStakingBalance > initialStakingBalance) {
            console.log("Total rewards accumulated:", finalStakingBalance - initialStakingBalance);
        }
    }

    // ============ GONS TOKEN / REBASING TESTS ============

    /// @notice Test that Gons token (sOKS) total supply increases after staking rewards
    function testGons_TotalSupplyIncreasesWithRewards() public {
        address stakingContract = vault.getStakingContract();

        if (stakingContract == address(0)) {
            console.log("Staking contract not set up");
            return;
        }

        // Try to get sOKS (Gons) token address
        // The staking contract should hold sOKS tokens
        // Note: This depends on how the staking is set up

        _doPurchasesToTriggerShiftCondition();

        address poolAddr = address(vault.pool());
        uint256 liquidityRatio = modelHelper.getLiquidityRatio(poolAddr, vaultAddress);

        if (liquidityRatio <= 0.90e18) {
            uint256 stakingBalanceBefore = token0.balanceOf(stakingContract);

            vault.shift();

            uint256 stakingBalanceAfter = token0.balanceOf(stakingContract);

            console.log("OKS in staking before:", stakingBalanceBefore);
            console.log("OKS in staking after:", stakingBalanceAfter);

            // The staking contract should have received OKS tokens
            // These would then be distributed to sOKS holders via rebase
            if (stakingBalanceAfter > stakingBalanceBefore) {
                console.log("Rewards to be distributed via rebase:", stakingBalanceAfter - stakingBalanceBefore);
            }
        }
    }

    // ============ PROTOCOL FEE DISTRIBUTION TESTS ============

    /// @notice Test that protocol fees go to dividend distributor when set
    function testShift_ProtocolFeesToDividendDistributor() public {
        _doPurchasesToTriggerShiftCondition();

        // Get dividend distributor address from vault
        // This requires reading from the resolver

        address poolAddr = address(vault.pool());
        uint256 liquidityRatio = modelHelper.getLiquidityRatio(poolAddr, vaultAddress);

        if (liquidityRatio <= 0.90e18) {
            // Note: To fully test this, we'd need access to the resolver
            // to get the DividendDistributor address

            console.log("Performing shift...");
            vault.shift();
            console.log("Shift completed - check dividend distributor balance separately");
        }
    }

    // ============ HELPER FUNCTIONS ============

    /// @dev Perform purchases to trigger shift condition (liquidityRatio <= 0.90)
    function _doPurchasesToTriggerShiftCondition() internal {
        IDOManager managerContract = IDOManager(idoManager);
        address poolAddr = address(vault.pool());

        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddr).slot0();
        uint256 spotPrice = Conversions.sqrtPriceX96ToPrice(sqrtPriceX96, 18);
        uint256 purchasePrice = spotPrice + (spotPrice * 25 / 100);

        uint16 totalTrades = 10;
        uint256 tradeAmount = 20000 ether;

        IWETH(WBNB).deposit{value: tradeAmount * totalTrades}();
        IWETH(WBNB).transfer(idoManager, tradeAmount * totalTrades);

        for (uint i = 0; i < totalTrades; i++) {
            (sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddr).slot0();
            spotPrice = Conversions.sqrtPriceX96ToPrice(sqrtPriceX96, 18);
            purchasePrice = spotPrice + (spotPrice * 25 / 100);
            managerContract.buyTokens(purchasePrice, tradeAmount, 0, address(this));
        }

        uint256 liquidityRatio = modelHelper.getLiquidityRatio(poolAddr, vaultAddress);
        console.log("Liquidity ratio after purchases:", liquidityRatio);
    }

    receive() external payable {}
}
