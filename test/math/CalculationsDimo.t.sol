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

//forge test --match-path ./test/math/CalculationsDimo.t.sol -vv
contract CalculationsDimoTest is Test {

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
            receiver,
            address(factory), 
            address(provider), 
            address(dimoToken), 
            address(dimoCredit),
            licenseCostInUsd
        );

        factory.setLicense(address(license));
    }

    function test_1to1simpleCase() public {
        address invoker = vm.addr(0x666);
        address admin = vm.addr(0x999);
        license.grantRole(keccak256("LICENSE_ADMIN_ROLE"), admin); 

        uint256 amountUsdPerToken = 1 ether;
        testOracleSource.setAmountUsdPerToken(amountUsdPerToken);

        uint256 licenseCostUpdate = 1 ether;
        
        vm.startPrank(admin);
        license.setLicenseCost(licenseCostUpdate);
        vm.stopPrank();
        
        deal(address(dimoToken), invoker, 1 ether);

        ///@dev before
        uint256 balanceOf00a = dimoToken.balanceOf(invoker);
        assertEq(balanceOf00a, 1 ether);
        uint256 balanceOf00b = dimoToken.balanceOf(receiver);
        assertEq(balanceOf00b, 0);
        
        vm.startPrank(invoker);
        dimoToken.approve(address(license), 1 ether);
        license.issueInDimo();
        vm.stopPrank();

        ///@dev after
        uint256 balanceOf01a = dimoToken.balanceOf(invoker);
        assertEq(balanceOf01a, 0);
        uint256 balanceOf01b = dimoToken.balanceOf(receiver);
        assertEq(balanceOf01b, 1 ether);
    }

    function test_calculate() public {
        address invoker = vm.addr(0x666);
        address admin = vm.addr(0x999);
        license.grantRole(keccak256("LICENSE_ADMIN_ROLE"), admin); 

        uint256 amountUsdPerToken = 0.25 ether; //250000000000000000
        testOracleSource.setAmountUsdPerToken(amountUsdPerToken);

        uint256 licenseCostUpdate = 2 ether;
        
        vm.startPrank(admin);
        license.setLicenseCost(licenseCostUpdate);
        vm.stopPrank();
        
        deal(address(dimoToken), invoker, 8 ether);

        ///@dev before
        uint256 balanceOf00a = dimoToken.balanceOf(invoker);
        assertEq(balanceOf00a, 8 ether);
        uint256 balanceOf00b = dimoToken.balanceOf(receiver);
        assertEq(balanceOf00b, 0);
        
        vm.startPrank(invoker);
        dimoToken.approve(address(license), 8 ether);
        license.issueInDimo();
        vm.stopPrank();

        ///@dev after
        uint256 balanceOf01a = dimoToken.balanceOf(invoker);
        assertEq(balanceOf01a, 0);
        uint256 balanceOf01b = dimoToken.balanceOf(receiver);
        assertEq(balanceOf01b, 8 ether);
    }

}
