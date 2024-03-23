// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IDimoToken} from "../../src/interface/IDimoToken.sol";

import {BaseSetUp} from "../helper/BaseSetUp.t.sol";

interface IGrantRole {
    function grantRole(bytes32 role, address account) external;
}

//forge test --match-path ./test/DevLicenseLock.t.sol -vv
contract DevLicenseDimoTest is BaseSetUp {

    uint256 tokenId;
    address clientId;

    function setUp() public {
        _setUp();

        (tokenId, clientId) = license.issueInDimo();    

        vm.startPrank(0xCED3c922200559128930180d3f0bfFd4d9f4F123);
        IDimoToken(address(dimoToken)).grantRole(keccak256("BURNER_ROLE"), address(license));
        vm.stopPrank();
    }

    function test_lockSuccess() public { 
        uint256 amount00 = 1 ether;
        license.lock(tokenId, amount00); 

        assertEq(license.licenseStaked(tokenId), amount00);
        assertEq(dimoToken.balanceOf(address(license)), amount00);
    }

    function test_burnStakeSuccess() public { 
        bytes32 role = license.LICENSE_ADMIN_ROLE();
        license.grantRole(role, address(this));
        bool hasRole = license.hasRole(role, address(this));
        assertEq(hasRole, true);

        uint256 amount00 = 1 ether;
        license.lock(tokenId, amount00); 

        assertEq(license.licenseStaked(tokenId), amount00);
        assertEq(dimoToken.balanceOf(address(license)), amount00);
        license.adminBurnLockedFunds(tokenId, amount00);
        
        assertEq(dimoToken.balanceOf(address(license)), 0);
    }

    
}
