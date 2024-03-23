// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {ForkProvider} from "../helper/ForkProvider.sol";
import {IDimoToken} from "../../src/interface/IDimoToken.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {DimoCredit} from "../../src/DimoCredit.sol";
import {TestOracleSource} from "../helper/TestOracleSource.sol";
import {NormalizedPriceProvider} from "../../src/provider/NormalizedPriceProvider.sol";

//forge test --match-path ./test/credits/DcCalc.t.sol -vv
contract DcCalcTest is Test {

    DimoCredit dc;
    IDimoToken dimoToken;

    address receiver;
    TestOracleSource oracle;
    NormalizedPriceProvider provider;

    function setUp() public {
        ForkProvider fork = new ForkProvider();
        vm.createSelectFork(fork._url(), 50573735);

        dimoToken = IDimoToken(0xE261D618a959aFfFd53168Cd07D12E37B26761db);

        receiver = address(0x123);

        oracle = new TestOracleSource();
        oracle.setAmountUsdPerToken(2 ether);
        
        provider = new NormalizedPriceProvider();
        provider.grantRole(keccak256("PROVIDER_ADMIN_ROLE"), address(this)); 
        provider.addOracleSource(address(oracle));
        
        dc = new DimoCredit(receiver, address(provider));
    }
    
    function test_calc() public {

        address user = address(0x1337);
        
        deal(address(dimoToken), user, 100 ether);

        vm.startPrank(user);
        dimoToken.approve(address(dc), 100 ether);
        vm.stopPrank();
  
        dc.mint(user, 100 ether, ""); 

        uint256 balanceOf01 = ERC20(address(dc)).balanceOf(user);
        assertEq(balanceOf01, 200_000 ether);

        uint256 balanceOf00 = ERC20(address(dimoToken)).balanceOf(user);
        assertEq(balanceOf00, 0);
        
        uint256 balanceOf02 = ERC20(address(dimoToken)).balanceOf(receiver);
        assertEq(balanceOf02, 100 ether);
    }

   
   
}
