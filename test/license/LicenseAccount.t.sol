// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {DimoDeveloperLicenseAccount} from "../../src/DimoDeveloperLicenseAccount.sol";
import {LicenseAccountFactory} from "../../src/LicenseAccountFactory.sol";
import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";

import {DevLicenseDimo} from "../../src/DevLicenseDimo.sol";
import {IDimoToken} from "../../src/interface/IDimoToken.sol";
import {NormalizedPriceProvider} from "../../src/provider/NormalizedPriceProvider.sol";
import {IDimoCredit} from "../../src/interface/IDimoCredit.sol";
import {DimoCredit} from "../../src/DimoCredit.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {TestOracleSource} from "../helper/TestOracleSource.sol";

//forge test --match-path ./test/LicenseAccount.t.sol -vv
contract LicenseAccountTest is Test {

    IDimoToken dimoToken;
    DimoCredit dimoCredit;
    DevLicenseDimo devLicense;
    LicenseAccountFactory factory;

    function setUp() public {
        //vm.createSelectFork('https://polygon-mainnet.g.alchemy.com/v2/NlPy1jSLyP-tUCHAuilxrsfaLcFaxSTm', 50573735);
        vm.createSelectFork('https://polygon-mainnet.infura.io/v3/89d890fd291a4096a41aea9b3122eb28', 50573735);
        dimoToken = IDimoToken(0xE261D618a959aFfFd53168Cd07D12E37B26761db);

        TestOracleSource testOracleSource = new TestOracleSource();
        uint256 amountUsdPerToken = 1 ether;
        testOracleSource.setAmountUsdPerToken(amountUsdPerToken);

        NormalizedPriceProvider provider = new NormalizedPriceProvider();
        provider.grantRole(keccak256("PROVIDER_ADMIN_ROLE"), address(this)); 
        provider.addOracleSource(address(testOracleSource));

        dimoCredit = new DimoCredit(address(0x123), address(provider)); 

        factory = new LicenseAccountFactory();

        uint256 licenseCostInUsd1e18 = 100 ether;

        devLicense = new DevLicenseDimo(
            address(0x888),
            address(factory), 
            address(provider), 
            address(dimoToken), 
            address(dimoCredit),
            licenseCostInUsd1e18
        );

        factory.setLicense(address(devLicense));
    }

    function test_initTemplateNotEffectClone() public { 
        DimoDeveloperLicenseAccount(factory._template()).initialize(1, address(0x999));

        deal(address(dimoToken), address(this), 1_000_000 ether);
        dimoToken.approve(address(devLicense), 1_000_000 ether);

        (uint256 tokenId00, address clientId00) = devLicense.issueInDimo();
        //console2.log("tokenId00: %s", tokenId00);
        assertEq(tokenId00, 1);

        vm.expectRevert("DimoDeveloperLicenseAccount: invalid operation");
        DimoDeveloperLicenseAccount(clientId00).initialize(tokenId00, address(devLicense));

        (uint256 tokenId01,) = devLicense.issueInDimo();
        //console2.log("tokenId01: %s", tokenId01);
        assertEq(tokenId01, 2);
    }

    /**
     */
    function test_ReInitFail() public { 
        deal(address(dimoToken), address(this), 1_000_000 ether);
        dimoToken.approve(address(devLicense), 1_000_000 ether);

        (uint256 tokenId, address clientId) = devLicense.issueInDimo();

        vm.expectRevert("DimoDeveloperLicenseAccount: invalid operation");
        DimoDeveloperLicenseAccount(clientId).initialize(tokenId, address(devLicense));
    }

    function test_redirectUri() public { 

        deal(address(dimoToken), address(this), 1_000_000 ether);
        dimoToken.approve(address(devLicense), 1_000_000 ether);

        (uint256 tokenId,) = devLicense.issueInDimo();   

        string memory uri = "https://www.dimo.zone";
        bool enabled = true;

        devLicense.setRedirectUri(tokenId, enabled, uri); 

        bool status = devLicense.redirectUriStatus(tokenId, uri);
        //console2.log("status: %s", status);
        assertEq(status, true);

        enabled = false;
        devLicense.setRedirectUri(tokenId, enabled, uri); 

        status = devLicense.redirectUriStatus(tokenId, uri);
        assertEq(status, false);

        devLicense.removeRedirectUri(tokenId, uri);
        status = devLicense.redirectUriStatus(tokenId, uri);
        assertEq(status, false);
    }

    
}
