// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {OracleSource} from "../../src/provider/OracleSource.sol";

/**
 */
contract TestOracleSource is OracleSource {

    constructor() {
        _amountUsdPerToken = 1;
        _updateTimestamp = 1701349809;
    }

    function setAmountUsdPerToken(uint256 amountUsdPerToken_) external {
        _amountUsdPerToken = amountUsdPerToken_;
    }

    /** 
     * 
     */

    function amountUsdPerToken() external view returns (uint256 amountUsdPerToken_) {
        amountUsdPerToken_ = _amountUsdPerToken;
    }
    
    function getAmountUsdPerToken() external view returns (uint256 amountUsdPerToken_, uint256 updateTimestamp) {
        return (_amountUsdPerToken, _updateTimestamp);
    }

    function getAmountUsdPerToken(bytes calldata /*data*/) external view returns (uint256 /*amountUsdPerToken*/, uint256 /*updateTimestamp*/) {
        return this.getAmountUsdPerToken();
    }

}
