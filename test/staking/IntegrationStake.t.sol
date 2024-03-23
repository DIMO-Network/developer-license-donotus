// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {ForkProvider} from "../helper/ForkProvider.sol";
import {TestOracleSource} from "../helper/TestOracleSource.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {DimoCredit} from "../../src/DimoCredit.sol";
import {IDimoCredit} from "../../src/interface/IDimoCredit.sol";
import {DevLicenseDimo} from "../../src/DevLicenseDimo.sol";
import {IDimoToken} from "../../src/interface/IDimoToken.sol";

import {NormalizedPriceProvider} from "../../src/provider/NormalizedPriceProvider.sol";
import {LicenseAccountFactory} from "../../src/LicenseAccountFactory.sol";


//forge test --match-path ./test/staking/IntegrationStake.t.sol -vv
contract IntegrationStakeTest is Test, ForkProvider {

    NormalizedPriceProvider provider;
    
    IDimoToken dimoToken;
    IDimoCredit dimoCredit;

    DevLicenseDimo license;
    
    address _dimoAdmin;

    function setUp() public {
        ForkProvider fork = new ForkProvider();
        vm.createSelectFork(fork._url(), 50573735);

        dimoToken = IDimoToken(0xE261D618a959aFfFd53168Cd07D12E37B26761db);

        provider = new NormalizedPriceProvider();
        provider.grantRole(keccak256("PROVIDER_ADMIN_ROLE"), address(this)); 
        TestOracleSource testOracleSource = new TestOracleSource();
        testOracleSource.setAmountUsdPerToken(1 ether);
        provider.addOracleSource(address(testOracleSource));

        LicenseAccountFactory laf = new LicenseAccountFactory();

        _dimoAdmin = address(0x666);
        vm.startPrank(_dimoAdmin);
        dimoCredit = IDimoCredit(address(new DimoCredit(address(0x123), address(provider))));
        license = new DevLicenseDimo(
            address(0x888),
            address(laf), 
            address(provider), 
            address(dimoToken), 
            address(dimoCredit),
            1 ether
        );
        vm.stopPrank();

        laf.setLicense(address(license));
    }
    
    function test_fuzzStake(uint256 amount) public {
        amount = bound(amount, 1.1 ether, type(uint256).max);
        
        address user = address(0x1337);
        
        deal(address(dimoToken), user, amount);

        uint256 balanceOf00 = ERC20(address(dimoToken)).balanceOf(user);
        assertEq(balanceOf00, amount);  

        vm.startPrank(user);
        dimoToken.approve(address(license), 1 ether);
        (uint256 tokenId,) = license.issueInDimo();
        vm.stopPrank();

        uint256 balanceOf01 = ERC20(address(dimoToken)).balanceOf(user);
        assertEq(balanceOf01, amount - 1 ether);

        vm.startPrank(user);
        dimoToken.approve(address(license), amount - 1 ether);
        license.lock(tokenId, amount - 1 ether);
        vm.stopPrank();

        assertEq(license.licenseStaked(tokenId), amount - 1 ether);

        vm.startPrank(_dimoAdmin);
        license.grantRole(license.LICENSE_ADMIN_ROLE(), _dimoAdmin);
        bool frozen = true;
        license.adminFreeze(tokenId, frozen);
        vm.stopPrank();

        vm.startPrank(user);
        uint256 amountWithdraw = license.licenseStaked(tokenId);
        vm.expectRevert("DevLicenseDimo: funds inaccessible");
        license.withdraw(tokenId, amountWithdraw);
        vm.stopPrank();
    }

  
}
