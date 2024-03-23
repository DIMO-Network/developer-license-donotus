// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC5192} from "../../src/interface/IERC5192.sol";
import {IERC721Metadata} from "openzeppelin-contracts/contracts/interfaces/IERC721Metadata.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {NormalizedPriceProvider} from "../../src/provider/NormalizedPriceProvider.sol";
import {LicenseAccountFactory} from "../../src/LicenseAccountFactory.sol";
import {TwapV3} from "../../src/provider/TwapV3.sol";

import {DimoCredit} from "../../src/DimoCredit.sol";
import {IDimoCredit} from "../../src/interface/IDimoCredit.sol";
import {DevLicenseDimo} from "../../src/DevLicenseDimo.sol";
import {IDimoToken} from "../../src/interface/IDimoToken.sol";
import {IDimoDeveloperLicenseAccount} from "../../src/interface/IDimoDeveloperLicenseAccount.sol";

//forge test --match-path ./test/RevokeBurnReallocate.t.sol -vv
contract RevokeBurnReallocateTest is Test {

    IDimoToken dimoToken;
    IDimoCredit dimoCredit;

    DevLicenseDimo license;
    NormalizedPriceProvider provider;

    address _dimoAdmin;

    function setUp() public {
        _dimoAdmin = address(0x666);

        //vm.createSelectFork('https://polygon-mainnet.g.alchemy.com/v2/NlPy1jSLyP-tUCHAuilxrsfaLcFaxSTm', 50573735);
        vm.createSelectFork('https://polygon-mainnet.infura.io/v3/89d890fd291a4096a41aea9b3122eb28', 50573735);
        dimoToken = IDimoToken(0xE261D618a959aFfFd53168Cd07D12E37B26761db);

        provider = new NormalizedPriceProvider();
        provider.grantRole(keccak256("PROVIDER_ADMIN_ROLE"), address(this)); 

        TwapV3 twap = new TwapV3();
        twap.grantRole(keccak256("ORACLE_ADMIN_ROLE"), address(this)); 
        uint32 intervalUsdc = 30 minutes;
        uint32 intervalDimo = 4 minutes; 
        twap.initialize(intervalUsdc, intervalDimo);
        provider.addOracleSource(address(twap));

        LicenseAccountFactory laf = new LicenseAccountFactory();

        vm.startPrank(_dimoAdmin);
        dimoCredit = IDimoCredit(address(new DimoCredit(address(0x123), address(provider))));
        license = new DevLicenseDimo(
            address(0x888),
            address(laf), 
            address(provider), 
            address(dimoToken), 
            address(dimoCredit),
            100
        );
        vm.stopPrank();

        laf.setLicense(address(license));
    }
    
    /**
     * revoke/burn a license
     */
    function test_burnSuccess() public {
        address user = address(0x2024);
        deal(address(dimoToken), user, 10_000 ether);
        
        vm.startPrank(user);
        dimoToken.approve(address(license), 10_000 ether);
        (uint256 tokenId,) = license.issueInDimo();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, 
            user, 
            license.REVOKER_ROLE())
        );
        license.revoke(tokenId);
        vm.stopPrank();

        address owner = license.ownerOf(tokenId);
        assertEq(owner, user);  

        vm.startPrank(_dimoAdmin);
        license.grantRole(keccak256("REVOKER_ROLE"), _dimoAdmin);
        license.revoke(tokenId);
        vm.stopPrank();

        vm.expectRevert("DevLicenseDimo: invalid tokenId");
        license.ownerOf(tokenId);
    }

    /**
     * reallocate someone's staked tokens
     */
    function test_reallocate() public {
        address owner = address(0x2024);
        deal(address(dimoToken), owner, 10_000 ether);
        
        vm.startPrank(owner);
        dimoToken.approve(address(license), 10_000 ether);
        dimoToken.approve(address(license), 10_000 ether);
        (uint256 tokenId,) = license.issueInDimo();
        vm.stopPrank();  

        uint256 amount99 = 1 ether;

        vm.startPrank(owner);
        license.lock(tokenId, amount99);
        vm.stopPrank();  

        uint256 amount00 = license.licenseStaked(tokenId);
        uint256 amount01 = dimoToken.balanceOf(address(license));
        assertEq(amount00, amount01);
        
        address to = address(0x999);
    
        bytes32 role = license.LICENSE_ADMIN_ROLE();
        vm.startPrank(_dimoAdmin);
        license.grantRole(role, _dimoAdmin);
        vm.stopPrank();

        vm.startPrank(_dimoAdmin);
        license.adminReallocate(tokenId, amount00, to);
        vm.stopPrank();

        uint256 amount02 = license.licenseStaked(tokenId);
        assertEq(amount02, 0);  

        uint256 amount0x = dimoToken.balanceOf(to);
        assertEq(amount0x, amount00);
    }

   // function test_burnFailLock() public {
        
    // }
    
}
