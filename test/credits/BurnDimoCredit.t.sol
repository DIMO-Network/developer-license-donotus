// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {DimoDeveloperLicenseAccount} from "../../src/DimoDeveloperLicenseAccount.sol";
import {LicenseAccountFactory} from "../../src/LicenseAccountFactory.sol";
import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";

import {IDimoToken} from "../../src/interface/IDimoToken.sol";
import {TwapV3} from "../../src/provider/TwapV3.sol";
import {NormalizedPriceProvider} from "../../src/provider/NormalizedPriceProvider.sol";
import {IDimoCredit} from "../../src/interface/IDimoCredit.sol";
import {DimoCredit} from "../../src/DimoCredit.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

//forge test --match-path ./test/BurnDimoCredit.t.sol -vv
contract BurnDimoCreditTest is Test {

    DimoCredit dc;
    IDimoToken dimoToken;
    NormalizedPriceProvider npp;

    function setUp() public {
        //vm.createSelectFork('https://polygon-mainnet.g.alchemy.com/v2/NlPy1jSLyP-tUCHAuilxrsfaLcFaxSTm', 50573735);
        vm.createSelectFork('https://polygon-mainnet.infura.io/v3/89d890fd291a4096a41aea9b3122eb28', 50573735);
        dimoToken = IDimoToken(0xE261D618a959aFfFd53168Cd07D12E37B26761db);

        TwapV3 twap = new TwapV3();
        twap.grantRole(keccak256("ORACLE_ADMIN_ROLE"), address(this)); 

        uint32 intervalUsdc = 30 minutes;
        uint32 intervalDimo = 4 minutes; 
        twap.initialize(intervalUsdc, intervalDimo);

        npp = new NormalizedPriceProvider();
        npp.grantRole(keccak256("PROVIDER_ADMIN_ROLE"), address(this)); 
        npp.addOracleSource(address(twap));

        dc = new DimoCredit(address(0x123), address(npp));

        dc.grantRole(keccak256("BURNER_ROLE"), address(this));   
    }

    /**
     */
    function test_burnSuccess() public { 
        address user = address(0x1337); 
        uint256 amountIn = 1 ether;
        bytes memory data = "";

        deal(address(dimoToken), user, amountIn);
        
        vm.startPrank(user);
        dimoToken.approve(address(dc), amountIn);
        uint256 amountDc = dc.mint(user, amountIn, data);
        vm.stopPrank();
        
        assertEq(dc.balanceOf(user), amountDc);

        dc.burn(user, amountDc);
        assertEq(dc.balanceOf(user), 0);
    }

    function test_burnFail() public { 
        address user = address(0x1337); 
        uint256 amountIn = 1 ether;
        bytes memory data = "";

        deal(address(dimoToken), user, amountIn);
        
        vm.startPrank(user);
        dimoToken.approve(address(dc), amountIn);
        uint256 amountDc = dc.mint(user, amountIn, data);
        vm.stopPrank();
        assertEq(dc.balanceOf(user), amountDc);

        vm.startPrank(address(0x123));
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, 
            address(0x123), 
            dc.BURNER_ROLE())
        );
        dc.burn(user, amountDc);
        vm.stopPrank();
    }

    function test_burnSuccessAddAddressBurnAgainSuccess() public { 
        address user = address(0x1337); 
        uint256 amountIn = 1 ether;
        bytes memory data = "";

        deal(address(dimoToken), user, amountIn);
        
        vm.startPrank(user);
        dimoToken.approve(address(dc), amountIn);
        uint256 amountDc = dc.mint(user, amountIn, data);
        vm.stopPrank();
        
        assertEq(dc.balanceOf(user), amountDc);

        dc.burn(user, 1);
        assertEq(dc.balanceOf(user), amountDc - 1);

        address next = address(0x123);

        dc.grantRole(keccak256("BURNER_ROLE"), next); 

        vm.startPrank(next);
        dc.burn(user, 1);
        vm.stopPrank();

        assertEq(dc.balanceOf(user), amountDc - 1 - 1);
    }

}
