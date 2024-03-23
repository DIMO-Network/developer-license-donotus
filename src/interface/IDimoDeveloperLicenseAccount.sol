// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IDimoDeveloperLicenseAccount {
    function initialize(uint256 tokenId, address license) external;
    function isValidSignature(bytes32 hashValue, bytes memory signature) external view returns (bytes4);
    function isSigner(address signer) external view returns(bool);
}