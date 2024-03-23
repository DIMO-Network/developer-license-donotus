// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";

import {TestOracleSource} from "../helper/TestOracleSource.sol";
import {DimoCredit} from "../../src/DimoCredit.sol";
import {IDimoToken} from "../../src/interface/IDimoToken.sol";
import {DevLicenseDimo} from "../../src/DevLicenseDimo.sol";
import {LicenseAccountFactory} from "../../src/LicenseAccountFactory.sol";
import {NormalizedPriceProvider} from "../../src/provider/NormalizedPriceProvider.sol";
import {IDimoDeveloperLicenseAccount} from "../../src/interface/IDimoDeveloperLicenseAccount.sol";

//forge test --match-path ./test/CalculationsDc.t.sol -vv
contract CalculationsDcTest is Test {

    DimoCredit dimoCredit;
    IDimoToken dimoToken;
    DevLicenseDimo license;

    NormalizedPriceProvider provider;
    TestOracleSource testOracleSource;

    uint256 licenseCostInUsd;

    address receiver;

    function setUp() public {
        //vm.createSelectFork('https://polygon-mainnet.g.alchemy.com/v2/NlPy1jSLyP-tUCHAuilxrsfaLcFaxSTm', 50573735);
        vm.createSelectFork('https://polygon-mainnet.infura.io/v3/89d890fd291a4096a41aea9b3122eb28', 50573735);
        dimoToken = IDimoToken(0xE261D618a959aFfFd53168Cd07D12E37B26761db);

        testOracleSource = new TestOracleSource();
        provider = new NormalizedPriceProvider();
        provider.grantRole(keccak256("PROVIDER_ADMIN_ROLE"), address(this)); 
        provider.addOracleSource(address(testOracleSource));

        LicenseAccountFactory factory = new LicenseAccountFactory();

        receiver = address(0x123);
        dimoCredit = new DimoCredit(receiver, address(provider));

        licenseCostInUsd = 0;
        license = new DevLicenseDimo(
            address(0x888),
            address(factory), 
            address(provider), 
            address(dimoToken), 
            address(dimoCredit),
            licenseCostInUsd
        );

        factory.setLicense(address(license));
    }

    function test_setDimoCreditRate() public {

        address admin = vm.addr(0x999);

        dimoCredit.grantRole(keccak256("DC_ADMIN_ROLE"), admin); 

        vm.startPrank(admin);
        dimoCredit.setDimoCreditRate(1 ether);
        vm.stopPrank();

    }

    function test_calcOneToOne() public {

        address admin = vm.addr(0x666);

        dimoCredit.grantRole(keccak256("DC_ADMIN_ROLE"), admin); 

        vm.startPrank(admin);
        dimoCredit.setDimoCreditRate(1 ether);
        vm.stopPrank();

        address to = vm.addr(0x123);
        
        uint256 licenseCostUpdate = 1 ether;
        license.grantRole(keccak256("LICENSE_ADMIN_ROLE"), admin);
        vm.startPrank(admin);
        license.setLicenseCost(licenseCostUpdate); 
        vm.stopPrank();

        testOracleSource = new TestOracleSource();
        testOracleSource.setAmountUsdPerToken(1 ether);

        provider.grantRole(keccak256("PROVIDER_ADMIN_ROLE"), address(this)); 
        provider.addOracleSource(address(testOracleSource));
        provider.setPrimaryOracleSource(1);

        uint256 amountIn = 1 ether;

        deal(address(dimoToken), to, amountIn);
        vm.startPrank(to);
        dimoToken.approve(address(dimoCredit), amountIn);
        vm.stopPrank();
    
        dimoCredit.mint(to, amountIn, "");

        dimoCredit.grantRole(keccak256("BURNER_ROLE"), address(license));
        
        vm.startPrank(to);
        (uint256 tokenId,) = license.issueInDc();
        vm.stopPrank();

        assertEq(tokenId, 1);

    }

}
