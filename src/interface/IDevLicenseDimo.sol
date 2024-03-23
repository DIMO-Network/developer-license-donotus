// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IDevLicenseDimo {
    function isSigner(uint256 tokenId, address account) external view returns (bool);
}