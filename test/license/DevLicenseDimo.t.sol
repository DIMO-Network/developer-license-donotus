// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DevLicenseDimo} from "../../src/DevLicenseDimo.sol";
import {DimoDeveloperLicenseAccount} from "../../src/DimoDeveloperLicenseAccount.sol";

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";

import {BaseSetUp} from "../helper/BaseSetUp.t.sol";

//forge test --match-path ./test/license/DevLicenseDimo.t.sol -vv
contract DevLicenseDimoTest is BaseSetUp {

    function setUp() public {
        _setUp();
    }

    function test_mintLicenseSuccess() public { 

        address receiver = address(0x999);

        license.grantRole(keccak256("LICENSE_ADMIN_ROLE"), address(this)); 
        license.setReceiverAddress(receiver);

        vm.expectEmit(true, true, false, false);
        emit DevLicenseDimo.Issued(1, address(this), address(0));
         
        (uint256 tokenId,) = license.issueInDimo();
        assertEq(tokenId, 1);

        assertEq(license.ownerOf(tokenId), address(this));

        (uint256 amountUsdPerToken,) = provider.getAmountUsdPerToken();
        uint256 tokenTransferAmount = (license._licenseCostInUsd1e18() / amountUsdPerToken) * 1 ether;

        assertEq(dimoToken.balanceOf(receiver), tokenTransferAmount);
    }

    function test_developerLicenseAccount() public {

        uint256 privateKey = 0x1337;
        address user = vm.addr(privateKey);

        deal(address(dimoToken), user, 1_000_000 ether);

        vm.startPrank(user);
        dimoToken.approve(address(license), 1_000_000 ether);
        (uint256 tokenId, address accountAddress) = license.issueInDimo();
        license.enableSigner(tokenId, user);
        vm.stopPrank();

        bytes32 hashValue = keccak256(
            abi.encodePacked(
                keccak256(
                    "\x19Ethereum Signed Message:\n32"
                ),
                keccak256("Hello World")
            )   
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hashValue);
        bytes memory signature = abi.encodePacked(r, s, v); 
        bytes4 output = DimoDeveloperLicenseAccount(accountAddress).isValidSignature(hashValue, signature);
        //console2.logBytes4(output);
        assertEq(IERC1271.isValidSignature.selector, output);
    }

    
}
