// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface ILicenseAccountFactory {
    function setLicense(address license) external;
    function create(uint256 tokenId) external returns (address clone);
}