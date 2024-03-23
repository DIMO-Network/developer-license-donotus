// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {DevLicenseDimo} from "../../src/DevLicenseDimo.sol";
import {DimoDeveloperLicenseAccount} from "../../src/DimoDeveloperLicenseAccount.sol";
import {LicenseAccountFactory} from "../../src/LicenseAccountFactory.sol";
import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {TwapV3} from "../../src/provider/TwapV3.sol";
import {NormalizedPriceProvider} from "../../src/provider/NormalizedPriceProvider.sol";
import {DimoCredit} from "../../src/DimoCredit.sol";

//forge test --match-path ./test/Integration.t.sol -vv
contract BaseSetUp is Test {

    ERC20 public dimoToken;
    DevLicenseDimo public license;

    DimoCredit public dimoCredit;
    NormalizedPriceProvider public provider;

    function _setUp() public {
        //vm.createSelectFork('https://polygon-mainnet.g.alchemy.com/v2/NlPy1jSLyP-tUCHAuilxrsfaLcFaxSTm', 50573735);
        vm.createSelectFork('https://polygon-mainnet.infura.io/v3/89d890fd291a4096a41aea9b3122eb28', 50573735);
        dimoToken = ERC20(0xE261D618a959aFfFd53168Cd07D12E37B26761db);

        LicenseAccountFactory laf = new LicenseAccountFactory();

        provider = new NormalizedPriceProvider();
        provider.grantRole(keccak256("PROVIDER_ADMIN_ROLE"), address(this)); 

        TwapV3 twap = new TwapV3();
        twap.grantRole(keccak256("ORACLE_ADMIN_ROLE"), address(this)); 
        
        uint32 intervalUsdc = 30 minutes;
        //console2.log("intervalUsdc: %s", intervalUsdc);
        uint32 intervalDimo = 4 minutes; 
        //console2.log("intervalDimo: %s", intervalDimo);
        twap.initialize(intervalUsdc, intervalDimo);
        provider.addOracleSource(address(twap));

        //(uint256 amountUsdPerToken, uint256 updateTimestamp) = provider.getAmountUsdPerToken();
        //console2.log("amountUsdPerToken: %s", amountUsdPerToken);
        //console2.log("  updateTimestamp: %s", updateTimestamp);

        dimoCredit = new DimoCredit(address(0x123), address(provider));

        uint256 licenseCostInUsd1e18 = 100 ether;

        license = new DevLicenseDimo(
            address(0x888),
            address(laf), 
            address(provider), 
            address(dimoToken), 
            address(dimoCredit),
            licenseCostInUsd1e18
        );

        laf.setLicense(address(license));
        deal(address(dimoToken), address(this), 1_000_000 ether);
        dimoToken.approve(address(license), 1_000_000 ether);
    }

    
}
