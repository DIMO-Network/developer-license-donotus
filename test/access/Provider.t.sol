// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {TwapV3} from "../../src/provider/TwapV3.sol";
import {TestOracleSource} from "../helper/TestOracleSource.sol";
import {NormalizedPriceProvider} from "../../src/provider/NormalizedPriceProvider.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

//forge test --match-path ./test/access/Provider.t.sol -vv
contract ProviderTest is Test {

    TwapV3 twap;
    TestOracleSource testOracleSource;
    NormalizedPriceProvider provider;

    function setUp() public {
        //vm.createSelectFork('https://polygon-mainnet.g.alchemy.com/v2/NlPy1jSLyP-tUCHAuilxrsfaLcFaxSTm', 50573735);
        vm.createSelectFork('https://polygon-mainnet.infura.io/v3/89d890fd291a4096a41aea9b3122eb28', 50573735);

        twap = new TwapV3();
        testOracleSource = new TestOracleSource();
        provider = new NormalizedPriceProvider();
    }
    
    function test_unitTestAccess() public {

        address adminOracle = address(0x666);
        
        twap.grantRole(keccak256("ORACLE_ADMIN_ROLE"), adminOracle); 

        vm.startPrank(adminOracle);
        uint32 intervalUsdc = 30 minutes;
        uint32 intervalDimo = 4 minutes; 
        twap.initialize(intervalUsdc, intervalDimo);
        vm.stopPrank();

        address adminProvider = address(0x777);

        provider.grantRole(keccak256("PROVIDER_ADMIN_ROLE"), adminProvider); 

        assertEq(provider._primaryIndex(), 0);
        
        vm.startPrank(adminProvider);
        provider.addOracleSource(address(twap));
        provider.addOracleSource(address(testOracleSource));
        provider.setPrimaryOracleSource(1);
        vm.stopPrank();

        assertEq(provider._primaryIndex(), 1);

        address updater = address(0x888);

        provider.grantRole(keccak256("UPDATER_ROLE"), updater); 

        vm.startPrank(updater);
        provider.updatePrice();
        vm.stopPrank();
        
    }

    function test_roleSwitchDeactivate() public {

        address adminOracle00 = address(0x666);
        address adminOracle01 = address(0x666);

        bytes32 role = keccak256("ORACLE_ADMIN_ROLE");
        
        twap.grantRole(role, adminOracle00); 

        vm.startPrank(adminOracle00);
        twap.initialize(30 minutes, 4 minutes);
        vm.stopPrank();

        twap.revokeRole(role, adminOracle00);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, 
            adminOracle00, 
            role)
        );
        vm.startPrank(adminOracle00);
        twap.initialize(30 minutes, 4 minutes);
        vm.stopPrank();

        twap.grantRole(role, adminOracle01); 

        vm.startPrank(adminOracle01);
        twap.initialize(31 minutes, 4.1 minutes);
        vm.stopPrank();
    }
   
}
