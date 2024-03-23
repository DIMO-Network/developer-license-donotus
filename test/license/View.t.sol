// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2} from "forge-std/Test.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC5192} from "../../src/interface/IERC5192.sol";
import {IERC721Metadata} from "openzeppelin-contracts/contracts/interfaces/IERC721Metadata.sol";
import {TestOracleSource} from "../helper/TestOracleSource.sol";

import {IDimoDeveloperLicenseAccount} from "../../src/interface/IDimoDeveloperLicenseAccount.sol";

import {BaseSetUp} from "../helper/BaseSetUp.t.sol";

//forge test --match-path ./test/View.t.sol -vv
contract ViewTest is BaseSetUp {

    uint256 _licenseCostInUsd;

    function setUp() public {
        _setUp();
        _licenseCostInUsd = 100 ether;
    }

    function test_existsLocked() public {
        (uint256 tokenId,) = license.issueInDimo();
        bool locked = license.locked(tokenId);
        assertEq(locked, true);
        vm.expectRevert("DevLicenseDimo: invalid tokenId");
        license.locked(300);
    }

    function test_ownerOfSuccess() public {
        (uint256 tokenId,) = license.issueInDimo();
        assertEq(license.ownerOf(tokenId), address(this));
    }

    function test_ownerOfFail() public {
        vm.expectRevert("DevLicenseDimo: invalid tokenId");
        license.ownerOf(type(uint256).max);
    }

    function test_name() public {
        string memory name = license.name();
        //console2.log("name: %s", name);
        assertEq(name, "DIMO Developer License");
    }

    function test_symbol() public {
        string memory symbol = license.symbol();
        //console2.log("symbol: %s", symbol);
        assertEq(symbol, "DLX");
    }

    function test_isSignerSucceedFail() public {
        address admin = address(0x1337);
        deal(address(dimoToken), admin, 1_000_000 ether);
        
        vm.startPrank(admin);
        dimoToken.approve(address(license), 1_000_000 ether);
        vm.stopPrank();

        address signer00 = address(0x123);
        address signer01 = address(0x456);

        vm.startPrank(admin);
        (uint256 tokenId, address clientId) = license.issueInDimo();
        license.enableSigner(tokenId, signer00);
        vm.stopPrank();

        bool isSigner00 = IDimoDeveloperLicenseAccount(clientId).isSigner(signer00);
        assertEq(isSigner00, true);

        bool isSigner01 = IDimoDeveloperLicenseAccount(clientId).isSigner(signer01);
        assertEq(isSigner01, false);  
    }


    function test_isSignerExpired() public {
        address to = address(0x1989);
        uint256 amountIn = 1 ether;
        bytes memory data = "";

        TestOracleSource testOracleSource = new TestOracleSource();
        testOracleSource.setAmountUsdPerToken(1000 ether);
        provider.addOracleSource(address(testOracleSource));
        provider.setPrimaryOracleSource(1);

        deal(address(dimoToken), to, amountIn);
        vm.startPrank(to);
        dimoToken.approve(address(dimoCredit), amountIn);
        vm.stopPrank();
        dimoCredit.mint(to, amountIn, data);

        license.grantRole(keccak256("LICENSE_ADMIN_ROLE"), address(this)); 
        license.setLicenseCost(1 ether);
        dimoCredit.grantRole(keccak256("BURNER_ROLE"), address(license));
        
        (uint256 tokenId, address clientId) = license.issueInDc(to);
        ///@notice ^mint license to a user other than the caller (using DC)

        address signer = address(0x123);
        
        vm.startPrank(to);
        license.enableSigner(tokenId, signer);
        vm.stopPrank();

        bool isSigner00 = IDimoDeveloperLicenseAccount(clientId).isSigner(signer);
        assertEq(isSigner00, true);

        vm.warp(block.timestamp + 366 days);

        bool isSigner01 = IDimoDeveloperLicenseAccount(clientId).isSigner(signer);
        assertEq(isSigner01, false);
    }

    function test_supportsInterface() public {
        bytes4 interface721 = type(IERC721).interfaceId;
        bool supports721 = license.supportsInterface(interface721);
        assertEq(supports721, true);
    
        bytes4 interface5192 = type(IERC5192).interfaceId;
        bool supports5192 = license.supportsInterface(interface5192);
        assertEq(supports5192, true);

        bytes4 interface721Metadata = type(IERC721Metadata).interfaceId;
        bool supports721Metadata = license.supportsInterface(interface721Metadata);
        assertEq(supports721Metadata, true);         
    }

    function test_periodValidity() public {
        license.grantRole(license.LICENSE_ADMIN_ROLE(), address(this));
        
        address signer = address(0x123);
        (uint256 tokenId, address clientId) = license.issueInDimo();
        license.enableSigner(tokenId, signer);

        uint256 periodValidity00 = 365 days;
        assertEq(license._periodValidity(), periodValidity00);

        bool isSigner00 = IDimoDeveloperLicenseAccount(clientId).isSigner(signer);
        assertEq(isSigner00, true);

        uint256 periodValidity01 = 1;
        license.setPeriodValidity(periodValidity01);

        vm.warp(block.timestamp + 2);

        bool isSigner01 = IDimoDeveloperLicenseAccount(clientId).isSigner(signer);
        assertEq(isSigner01, false);  

        assertEq(license._periodValidity(), periodValidity01);
    }

    function test_licenseCostInUsd() public {
        license.grantRole(license.LICENSE_ADMIN_ROLE(), address(this));
        
        uint256 licenseCostInUsd00 = license._licenseCostInUsd1e18();

        license.grantRole(keccak256("LICENSE_ADMIN_ROLE"), address(this)); 
        license.setLicenseCost(0.5 ether);

        assertEq(licenseCostInUsd00, _licenseCostInUsd); 

        uint256 licenseCostInUsd01 = 0.1 ether;
        license.setLicenseCost(licenseCostInUsd01);

        address user = address(0x1999);

        vm.startPrank(user);
        dimoToken.approve(address(license), 0.05 ether);
        license.issueInDimo();
        vm.stopPrank();

        license.setLicenseCost(1_000_000 ether);

        vm.startPrank(user);
        vm.expectRevert();
        license.issueInDimo();
        vm.stopPrank();
    }
    
}
