// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {IDevLicenseDimo} from "./interface/IDevLicenseDimo.sol";

contract DimoDeveloperLicenseAccount is IERC1271 {
    IDevLicenseDimo private _license;
    uint256 private _tokenId;
    bool private _initialized;

    function initialize(uint256 tokenId_, address license_) public {
        require(!_initialized, "DimoDeveloperLicenseAccount: invalid operation");
        _license = IDevLicenseDimo(license_);
        _tokenId = tokenId_;
        _initialized = true;
    }

    function isSigner(address signer) public view returns(bool) {
        return _license.isSigner(_tokenId, signer);
    }

    function isValidSignature(bytes32 hashValue, bytes memory signature) external view returns (bytes4) {
        address recovered = ECDSA.recover(hashValue, signature);
        if (_license.isSigner(_tokenId, recovered)) {
            return IERC1271.isValidSignature.selector; //0x1626ba7e
        } else {
            return 0xffffffff;
        }
    }
}
