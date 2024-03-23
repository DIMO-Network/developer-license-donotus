// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {DimoDeveloperLicenseAccount} from "./DimoDeveloperLicenseAccount.sol";
import {ILicenseAccountFactory} from "./interface/ILicenseAccountFactory.sol";

/**
 * @title DIMO Developer License Account Factory
 * @custom:version 1.0.0
 * @author Sean Matt English (@smatthewenglish)
 * @custom:coauthor Lorran Sutter (@LorranSutter)
 * @custom:coauthor Dylan Moreland (@elffjs)
 * @custom:coauthor Yevgeny Khessin (@zer0stars)
 * @custom:coauthor Rob Solomon (@robmsolomon)
 * @custom:contributor Allyson English (@aesdfghjkl666)
 */
contract LicenseAccountFactory is Ownable2Step, ILicenseAccountFactory { 

    address public _template;
    address public _license; 

    constructor() Ownable(msg.sender) {
        _template = address(new DimoDeveloperLicenseAccount());
    }

    function setLicense(address license_) external onlyOwner {
        _license = license_;
    }

    /**
     * 
     */
    function create(uint256 tokenId) external returns (address clone) {
        clone = _createClone(address(_template));
        DimoDeveloperLicenseAccount(clone).initialize(tokenId, _license);
    }

    /**
     * @notice Creates clone of the license account contract, sharing 
     * business logic from the original,cbut with its own storage.
     *
     * @param target_ address of the contract to clone.
     * @return result address of the new cloned contract.
     */
    function _createClone(address target_) private returns (address result) {
        bytes20 targetBytes = bytes20(target_);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            result := create(0, clone, 0x37)
        }
    }

}