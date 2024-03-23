// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IOracleSource {

    function updatePrice() external;
    function isUpdatable() external view returns (bool updatable);
    
    /** 
     * @return amountUsdPerToken The amount of USD you would get in exchange for 1 $DIMO, with 18 decimal places
     * @return updateTimestamp The timestamp at which the price was last set
     **/
    function getAmountUsdPerToken() external returns (uint256 amountUsdPerToken, uint256 updateTimestamp);
    function getAmountUsdPerToken(bytes calldata data) external returns (uint256 amountUsdPerToken, uint256 updateTimestamp);

    function getAmountNativePerToken() external returns (uint256 amountNativePerToken, uint256 updateTimestamp);
    function getAmountNativePerToken(bytes calldata data) external returns (uint256 amountNativePerToken, uint256 updateTimestamp);
}


