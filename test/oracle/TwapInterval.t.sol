// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

import {TwapV3} from "../../src/provider/TwapV3.sol";

//forge test --match-path ./test/oracle/TwapInterval.t.sol -vv
contract TwapIntervalTest is Test {

    /**
     * @dev Because spot prices are easy and relatively cheap to manipulate, most protocols use a 
     * rolling 30-minute time window for TWAP to calculate the price3. Using TWAP with a long window 
     * causes prices to be smooth but lagging.
     * 
     * Since most protocols use a 30 minute running TWAP, waiting more blocks allows more of the total 
     * weighting on the final manipulated price.
     * 
     * https://blog.uniswap.org/uniswap-v3-oracles
     */
    TwapV3 twap;

    function setUp() public {
        //vm.createSelectFork('https://polygon-mainnet.g.alchemy.com/v2/NlPy1jSLyP-tUCHAuilxrsfaLcFaxSTm', 50573735);

        uint256 marchTwnetyFourPmEst = 54889372;
        vm.createSelectFork(
            'https://polygon-mainnet.infura.io/v3/89d890fd291a4096a41aea9b3122eb28', 
            marchTwnetyFourPmEst
        );

        // 1 USDC ~ 1.00428 MATIC
        // 1 DIMO ~ 0.44209 MATIC

        /* * */

        // 1 MATIC ~ 0.9943 USDC
        // 1 DIMO ~ 0.43966 USDC
        
        twap = new TwapV3();
    }
    
    function test_getAmountUsdPerToken() public {
        uint32 twapIntervalUsdc = 1 minutes;
        uint32 twapIntervalDimo = 1 minutes;
        twap.grantRole(keccak256("ORACLE_ADMIN_ROLE"), address(this)); 


        console2.logBytes32(keccak256("ORACLE_ADMIN_ROLE")); 

        twap.setTwapIntervalUsdc(twapIntervalUsdc);
        twap.setTwapIntervalDimo(twapIntervalDimo);

        (uint256 amountUsdPerToken, uint256 updateTimestamp) = twap.getAmountUsdPerToken();
        console2.log("amountUsdPerToken: %s", amountUsdPerToken); 
        console2.log("updateTimestamp: %s", updateTimestamp); 
        //439746722760396201
        //0.439746722760396201

        uint32 twapIntervalUsdc00 = twap.getIntervalUsdc();
        assertEq(1 minutes, twapIntervalUsdc00);

        uint32 twapIntervalDimo00 = twap.getIntervalDimo();
        assertEq(1 minutes, twapIntervalDimo00);

        assertEq(0.439746722760396201 ether, amountUsdPerToken);
    }

    function test_30minutes() public {
        (uint256 amountUsdPerToken,) = twap.getAmountUsdPerToken();
        console2.log("amountUsdPerToken: %s", amountUsdPerToken); 
        // 437503402621950580
        // 0.43750340262195058

        uint32 twapIntervalUsdc = twap.getIntervalUsdc();
        assertEq(30 minutes, twapIntervalUsdc);

        uint32 twapIntervalDimo = twap.getIntervalDimo();
        assertEq(30 minutes, twapIntervalDimo);

        assertEq(0.43750340262195058 ether, amountUsdPerToken);
    }


    /**
     * demonstrates how trading against the pool at different levels manipulates the price
     * https://docs.uniswap.org/contracts/v3/guides/swaps/single-swaps
     */
    function test_attack() public {
        (uint256 amountUsdPerToken00,) = twap.getAmountUsdPerToken();
        console2.log("amountUsdPerToken00: %s", amountUsdPerToken00); 

        address recipient = address(0x123);

        uint256 balanceOf0 = ERC20(0xE261D618a959aFfFd53168Cd07D12E37B26761db).balanceOf(recipient);
        console2.log("balanceOf0: %s", balanceOf0); 
        
        deal(address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270), address(this), 1_000_000 ether);

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
                tokenOut: 0xE261D618a959aFfFd53168Cd07D12E37B26761db,
                fee: 10000,
                recipient: recipient,
                deadline: block.timestamp,
                amountIn: 1_000 ether,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        
        ERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270).approve(address(0xE592427A0AEce92De3Edee1F18E0157C05861564), 1_000_000 ether);

        // The call to `exactInputSingle` executes the swap.
        uint256 amountOut = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564).exactInputSingle(params);
        console2.log("amountOut: %s", amountOut); 
        
        uint256 balanceOf1 = ERC20(0xE261D618a959aFfFd53168Cd07D12E37B26761db).balanceOf(recipient);
        console2.log("balanceOf1: %s", balanceOf1); 

        (uint256 amountUsdPerToken01,) = twap.getAmountUsdPerToken();
        console2.log("amountUsdPerToken01: %s", amountUsdPerToken01); 

        //437503402621950580 (0.43750340262195058) //1 in
        //437503946151832219 (0.437503946151832219)

        //437503402621950580 (0.43750340262195058) //100 in
        //437557757281360307 (0.437557757281360307)

        //437503402621950580 (0.43750340262195058) //1_000 in
        //438047101147491277 (0.438047101147491277)

        //437503402621950580 (0.43750340262195058) //1_000_000 in 
        //124693893367524554976331 (124693.893367524554976331)
        
    }
   
}
