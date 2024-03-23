// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IOracleSource} from "./IOracleSource.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title NormalizedPriceProvider
 * @custom:version 1.0.0
 * @author Sean Matt English (@smatthewenglish) 
 * @custom:coauthor Lorran Sutter (@LorranSutter)
 * @custom:coauthor Dylan Moreland (@elffjs)
 * @custom:coauthor Yevgeny Khessin (@zer0stars)
 * @custom:coauthor Rob Solomon (@robmsolomon)
 * @custom:contributor Allyson English (@aesdfghjkl666)
 * 
 * @dev Normalize the format of different oracle sources into a common source.
 */
contract NormalizedPriceProvider is AccessControl {

    /*//////////////////////////////////////////////////////////////
                             Access Controls
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    bytes32 public constant PROVIDER_ADMIN_ROLE = keccak256("PROVIDER_ADMIN_ROLE");

    uint256 public _primaryIndex;
    IOracleSource[] public _oracleSources;

    event PrimaryOracleSourceSet(uint256 indexed index);
    event OracleSourceRemoved(address indexed source);
    event OracleSourceAdded(address indexed source);

    uint256 constant MAX_ORACLE_SOURCES = 12;
    string constant private ERROR_INVALID_INDEX = "NormalizedPriceProvider: invalid index";
    string constant private ERROR_MAX_ORACLES_REACHED = "NormalizedPriceProvider: max oracle sources reached";

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function addOracleSource(address source) external onlyRole(PROVIDER_ADMIN_ROLE) {
        require(source != address(0), "NormalizedPriceProvider: invalid source address");
        require(_oracleSources.length < MAX_ORACLE_SOURCES, ERROR_MAX_ORACLES_REACHED);
        _oracleSources.push(IOracleSource(source));
        emit OracleSourceAdded(source);
    }

    function setPrimaryOracleSource(uint256 index) external onlyRole(PROVIDER_ADMIN_ROLE) {
        require(index < _oracleSources.length, ERROR_INVALID_INDEX);
        _primaryIndex = index;
        emit PrimaryOracleSourceSet(_primaryIndex);
    }

    /**
     * Remove the oracle source from the array by swapping it with 
     * the last element and then popping from the array
     */
    function removeOracleSource(uint256 indexToRemove) external onlyRole(PROVIDER_ADMIN_ROLE) {
        require(indexToRemove < _oracleSources.length && 
                indexToRemove != _primaryIndex, ERROR_INVALID_INDEX);

        emit OracleSourceRemoved(address(_oracleSources[indexToRemove]));
        
        _oracleSources[indexToRemove] = _oracleSources[_oracleSources.length - 1];
        _oracleSources.pop();
    }

    /**
     * This function costs us $LINK and costs the caller gas.
     */
    function updatePrice() external onlyRole(UPDATER_ROLE) {
        _oracleSources[_primaryIndex].updatePrice();
    }

    function getPrimaryOracleSource() external view returns (address primaryOracleSource) {
        primaryOracleSource = address(_oracleSources[_primaryIndex]);
    }

    function getAllOracleSources() external view returns (address[] memory) {
        address[] memory oracleSources = new address[](_oracleSources.length);
        for(uint256 i = 0; i < _oracleSources.length; i++) {
            oracleSources[i] = address(_oracleSources[i]);
        }
        return oracleSources;
    }

    function getAmountUsdPerToken() public returns (uint256 amountUsdPerToken, uint256 updateTimestamp) {
        (amountUsdPerToken, updateTimestamp) = this.getAmountUsdPerToken("");
    }

    function getAmountUsdPerToken(bytes calldata data) public returns (uint256 amountUsdPerToken, uint256 updateTimestamp) {
        (amountUsdPerToken, updateTimestamp) = _oracleSources[_primaryIndex].getAmountUsdPerToken(data);
    }

    function isUpdatable() external view returns (bool updatable) {
        updatable = _oracleSources[_primaryIndex].isUpdatable();
    }

}
