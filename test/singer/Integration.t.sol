// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2} from "forge-std/Test.sol";

import {BaseSetUp} from "../helper/BaseSetUp.t.sol";

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";

import {IDimoDeveloperLicenseAccount} from "../../src/interface/IDimoDeveloperLicenseAccount.sol";

//forge test --match-path ./test/Integration.t.sol -vv
contract IntegrationTest is BaseSetUp {

    uint256 tokenId;
    address clientId;

    function setUp() public {
        _setUp();

        (tokenId, clientId) = license.issueInDimo();
        assertEq(tokenId, 1);
        assertEq(license.ownerOf(tokenId), address(this));
    }

    function test_integration00() public {   
        ///@notice oauth client created for you on the backend

        ///@dev add redirect url
        string memory uri = "https://www.test.com/";
        license.setRedirectUri(tokenId, true, uri);

        ///@notice check that the backend has that

        ///@dev add a signer, with a known pk
        uint256 privateKey = 0x1337;
        address signer = vm.addr(privateKey);
        
        license.enableSigner(tokenId, signer);

        bytes32 hashValue = keccak256(
            abi.encodePacked(
                keccak256(
                    "\x19Ethereum Signed Message:\n32" //32 length of message...
                ),
                keccak256("challenge message")
            )   
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hashValue);
        bytes memory signature = abi.encodePacked(r, s, v); 
        bytes4 output = IDimoDeveloperLicenseAccount(clientId).isValidSignature(hashValue, signature);

        ///@dev use that signer to sign a challenge message for that license
        assertEq(IERC1271.isValidSignature.selector, output);

        ///@notice check that you can log in as the license address
    }

}
