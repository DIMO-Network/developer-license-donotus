// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IOracleSource} from "./IOracleSource.sol";

/**
 * multiple oracle sources queued up ready to go, because if
 * one of the starts malfunctioning we'd want to switch it to
 * another "one on the fly", rather than code up and deploy
 * a new smart contract for it
 */
abstract contract OracleSource {

    /*//////////////////////////////////////////////////////////////
                             Access Controls
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN_ROLE");

    uint256 public _updateTimestamp;
    uint256 public _amountUsdPerToken;

    event NewPrice(
        address source,
        uint256 amountUsdPerToken,
        uint256 updateTimestamp
    );

    function _newPrice() internal {
        emit NewPrice(address(this), _amountUsdPerToken, _updateTimestamp);
    }

    function isUpdatable() external virtual pure returns (bool updatable) {
        updatable = false;
    }

    function updatePrice() external virtual {}

    function getAmountNativePerToken() external returns (uint256 amountNativePerToken, uint256 updateTimestamp) {}

    function getAmountNativePerToken(bytes calldata data) external returns (uint256 amountNativePerToken, uint256 updateTimestamp) {}

}