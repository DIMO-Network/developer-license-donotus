// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {OracleSource} from "../provider/OracleSource.sol";

/**
 */
contract MockOracleSource is OracleSource {

    constructor() {}

    /** 
     * 
     */
    function getAmountUsdPerToken() external pure returns (uint256 amountUsdPerToken, uint256 updateTimestamp) {
        uint256 _amountUsdPerToken = 110262839782427950;
        uint256 _updateTimestamp = 1701349809;
        return (_amountUsdPerToken, _updateTimestamp);
    }

    function getAmountUsdPerToken(bytes calldata /*data*/) external view returns (uint256 /*amountUsdPerToken*/, uint256 /*updateTimestamp*/) {
        return this.getAmountUsdPerToken();
    }

}
