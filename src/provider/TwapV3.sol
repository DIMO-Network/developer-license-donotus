// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {FixedPoint96} from "@uniswap/v4-core/src/libraries/FixedPoint96.sol";
import {OracleSource} from "./OracleSource.sol";

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title TwapV3
 * @custom:version 1.0.0
 * @author Sean Matt English (@smatthewenglish)
 * @custom:coauthor Lorran Sutter (@LorranSutter)
 * @custom:coauthor Dylan Moreland (@elffjs)
 * @custom:coauthor Yevgeny Khessin (@zer0stars)
 * @custom:coauthor Rob Solomon (@robmsolomon)
 * @custom:contributor Allyson English (@aesdfghjkl666)
 */
contract TwapV3 is OracleSource, AccessControl {
    address public immutable poolWmaticUsdc;
    address public immutable poolWmaticDimo;

    uint32 _twapIntervalUsdc;
    uint32 _twapIntervalDimo;

    uint256 constant SCALING_FACTOR = 1 ether;

    constructor() {
        _twapIntervalUsdc = 30 minutes;
        _twapIntervalDimo = 30 minutes;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        poolWmaticUsdc = 0xB6e57ed85c4c9dbfEF2a68711e9d6f36c56e0FcB;
        poolWmaticDimo = 0x41e64a5Bc929fA8E6a9C8d7E3b81A13b21Ff3045;
    }

    function initialize(
        uint32 twapIntervalUsdc_, 
        uint32 twapIntervalDimo_) external onlyRole(ORACLE_ADMIN_ROLE) {
        _twapIntervalUsdc = twapIntervalUsdc_;
        _twapIntervalDimo = twapIntervalDimo_;
    }

    function getIntervalUsdc() external view returns (uint32 twapIntervalUsdc_) {
        twapIntervalUsdc_ = _twapIntervalUsdc;
    }

    function setTwapIntervalUsdc(uint32 twapIntervalUsdc_) external onlyRole(ORACLE_ADMIN_ROLE) {
        _twapIntervalUsdc = twapIntervalUsdc_;
    }

    function getIntervalDimo() external view returns (uint32 twapIntervalDimo_) {
        twapIntervalDimo_ = _twapIntervalDimo;
    }

    function setTwapIntervalDimo(uint32 twapIntervalDimo_) external onlyRole(ORACLE_ADMIN_ROLE) {
        _twapIntervalDimo = twapIntervalDimo_;
    }

    /** 
     * 
     */
    function getAmountUsdPerToken()
        external
        returns (uint256 amountUsdPerToken, uint256 updateTimestamp)
    {
        //$USDC
        uint160 sqrtPriceUsdcX96 = getSqrtTwapX96(poolWmaticUsdc, _twapIntervalUsdc);
        uint256 priceUsdcX96 = getPriceX96FromSqrtPriceX96(sqrtPriceUsdcX96);
        uint256 priceInWeiUsdc = _getPriceInWei(priceUsdcX96) * 1e12;

        //$DIMO
        uint160 sqrtPriceDimoX96 = getSqrtTwapX96(poolWmaticDimo, _twapIntervalDimo);
        uint256 priceDimoX96 = getPriceX96FromSqrtPriceX96(sqrtPriceDimoX96);
        uint256 priceDimoInWei = _getPriceInWei(priceDimoX96);

        _amountUsdPerToken = (priceInWeiUsdc * SCALING_FACTOR) / priceDimoInWei;
        _updateTimestamp = block.timestamp;
        _newPrice();

        return (_amountUsdPerToken, _updateTimestamp);
    }

    function getAmountUsdPerToken(bytes calldata /*data*/) external returns (uint256 /*amountUsdPerToken*/, uint256 /*updateTimestamp*/) {
        return this.getAmountUsdPerToken();
    }

    function _getPriceInWei(uint256 priceX96) public pure returns (uint256 priceInWei) {
        priceInWei = (priceX96 * SCALING_FACTOR) / (1 << 96);
    }

    /**
     *   
     */
    function getSqrtTwapX96(address uniswapV3Pool, uint32 twapInterval) public view returns (uint160 sqrtPriceX96) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapInterval; // from (before)
        secondsAgos[1] = 0; // to (now)

        int56[] memory tickCumulatives;
        try IUniswapV3Pool(uniswapV3Pool).observe(secondsAgos) returns (int56[] memory tickCumulatives_, uint160[] memory /*secondsPerLiquidityCumulativeX128s*/) {
            tickCumulatives = tickCumulatives_;
        } catch {
            // return the current price in the event of interval induced error
            (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(uniswapV3Pool).slot0();
            return sqrtPriceX96;
        }

        // tick(imprecise as it's an integer) to price
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
            int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapInterval)))
        );
    }

    function getPriceX96FromSqrtPriceX96(uint160 sqrtPriceX96) public pure returns(uint256 priceX96) {
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }


}
