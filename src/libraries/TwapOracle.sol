// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "v3-core/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";

/**
 * @title TwapOracle
 * @notice Library for fetching TWAP (Time-Weighted Average Price) from Uniswap V3 pools.
 * @dev Uses the pool's built-in oracle to get manipulation-resistant price data.
 *
 * MEV PROTECTION STRATEGY:
 * ========================
 * The spot price from slot0() can be manipulated within a single block via flash loans
 * or sandwich attacks. TWAP uses historical tick observations that span multiple blocks,
 * making manipulation economically infeasible (attacker would need to sustain the
 * manipulated price across many blocks).
 *
 * Usage in shift():
 * - Instead of: (uint160 sqrtRatioX96,,,,,,) = pool.slot0();
 * - Use: int24 twapTick = TwapOracle.getTwapTick(pool, 1800); // 30-min TWAP
 *        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(twapTick);
 */
library TwapOracle {
    /// @notice Minimum TWAP period to provide meaningful protection (5 minutes)
    uint32 public constant MIN_TWAP_PERIOD = 300;

    /// @notice Default TWAP period if none specified (30 minutes)
    uint32 public constant DEFAULT_TWAP_PERIOD = 1800;

    /**
     * @notice Get the TWAP tick over a specified period.
     * @param pool The Uniswap V3 pool address
     * @param twapPeriod Seconds to look back (e.g., 1800 = 30 minutes)
     * @return twapTick The time-weighted average tick
     * @dev Reverts if the pool doesn't have enough observation history.
     *      Call increaseObservationCardinalityNext() on the pool if needed.
     */
    function getTwapTick(
        address pool,
        uint32 twapPeriod
    ) internal view returns (int24 twapTick) {
        if (twapPeriod < MIN_TWAP_PERIOD) {
            twapPeriod = MIN_TWAP_PERIOD;
        }

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapPeriod; // Start of period (in the past)
        secondsAgos[1] = 0;          // End of period (now)

        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(secondsAgos);

        // TWAP tick = (tickCumulative[now] - tickCumulative[past]) / period
        int56 tickCumulativeDelta = tickCumulatives[1] - tickCumulatives[0];
        twapTick = int24(tickCumulativeDelta / int56(int32(twapPeriod)));

        // Round towards negative infinity (Uniswap convention)
        if (tickCumulativeDelta < 0 && (tickCumulativeDelta % int56(int32(twapPeriod)) != 0)) {
            twapTick--;
        }
    }

    /**
     * @notice Get the TWAP sqrtPriceX96 over a specified period.
     * @param pool The Uniswap V3 pool address
     * @param twapPeriod Seconds to look back
     * @return sqrtPriceX96 The TWAP price in sqrtPriceX96 format
     */
    function getTwapSqrtPriceX96(
        address pool,
        uint32 twapPeriod
    ) internal view returns (uint160 sqrtPriceX96) {
        int24 twapTick = getTwapTick(pool, twapPeriod);
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(twapTick);
    }

    /**
     * @notice Get both spot and TWAP ticks for comparison.
     * @param pool The Uniswap V3 pool address
     * @param twapPeriod Seconds to look back for TWAP
     * @return spotTick Current tick from slot0
     * @return twapTick Time-weighted average tick
     * @return deviationTicks Absolute deviation in ticks (~1 tick ≈ 0.01% price)
     */
    function getSpotVsTwap(
        address pool,
        uint32 twapPeriod
    ) internal view returns (
        int24 spotTick,
        int24 twapTick,
        uint256 deviationTicks
    ) {
        (, spotTick, , , , , ) = IUniswapV3Pool(pool).slot0();
        twapTick = getTwapTick(pool, twapPeriod);

        int256 tickDelta = int256(spotTick) - int256(twapTick);
        deviationTicks = tickDelta >= 0 ? uint256(tickDelta) : uint256(-tickDelta);
    }

    /**
     * @notice Check if spot price deviates too much from TWAP.
     * @param pool The Uniswap V3 pool address
     * @param twapPeriod Seconds to look back for TWAP
     * @param maxDeviationTicks Maximum allowed deviation in ticks
     * @return isManipulated True if deviation exceeds threshold
     * @return deviationTicks Actual deviation in ticks
     */
    function isSpotManipulated(
        address pool,
        uint32 twapPeriod,
        uint256 maxDeviationTicks
    ) internal view returns (bool isManipulated, uint256 deviationTicks) {
        (, , deviationTicks) = getSpotVsTwap(pool, twapPeriod);
        isManipulated = deviationTicks > maxDeviationTicks;
    }

    /**
     * @notice Get a manipulation-resistant tick for position calculations.
     * @param pool The Uniswap V3 pool address
     * @param twapPeriod Seconds to look back (0 = use spot price for backwards compatibility)
     * @return tick The tick to use for calculations (TWAP if period > 0, else spot)
     * @return sqrtPriceX96 The corresponding sqrtPriceX96
     */
    function getSafeTick(
        address pool,
        uint32 twapPeriod
    ) internal view returns (int24 tick, uint160 sqrtPriceX96) {
        if (twapPeriod == 0) {
            // Backwards compatible: use spot price (NOT RECOMMENDED for MEV protection)
            (sqrtPriceX96, tick, , , , , ) = IUniswapV3Pool(pool).slot0();
        } else {
            // Use TWAP for MEV protection
            tick = getTwapTick(pool, twapPeriod);
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
        }
    }

    /**
     * @notice Check if the pool's oracle can support a given TWAP period.
     * @param pool The Uniswap V3 pool address
     * @param twapPeriod The desired TWAP lookback period
     * @return canSupport Whether the oracle has enough history
     * @return currentCardinality Current observation cardinality
     * @return recommendedCardinality Recommended cardinality for the period
     */
    function checkOracleSupport(
        address pool,
        uint32 twapPeriod
    ) internal view returns (
        bool canSupport,
        uint16 currentCardinality,
        uint16 recommendedCardinality
    ) {
        (, , , currentCardinality, , , ) = IUniswapV3Pool(pool).slot0();

        // Estimate required cardinality (assuming ~3 second blocks for BSC)
        // Add buffer for safety
        recommendedCardinality = uint16((twapPeriod / 3) + 10);

        // The actual test is whether observe() works - cardinality just tells us
        // allocated slots, not filled observations
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapPeriod;
        secondsAgos[1] = 0;

        try IUniswapV3Pool(pool).observe(secondsAgos) {
            // Success - oracle has enough observation history
            canSupport = true;
        } catch {
            // observe() failed - not enough history yet
            canSupport = false;
        }
    }

    /**
     * @notice Increase the pool's observation cardinality for TWAP support.
     * @param pool The Uniswap V3 pool address
     * @param targetCardinality The desired observation cardinality
     * @dev This is a one-time setup that anyone can call.
     *      Higher cardinality = longer TWAP periods supported.
     *      Recommended: 300+ for 1-hour TWAP on 12-second block chains.
     */
    function ensureOracleCardinality(
        address pool,
        uint16 targetCardinality
    ) internal {
        (, , , , uint16 cardinalityNext, , ) = IUniswapV3Pool(pool).slot0();

        if (cardinalityNext < targetCardinality) {
            IUniswapV3Pool(pool).increaseObservationCardinalityNext(targetCardinality);
        }
    }
}
