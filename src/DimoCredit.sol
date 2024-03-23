// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IDimoToken} from "./interface/IDimoToken.sol";
import {NormalizedPriceProvider} from "./provider/NormalizedPriceProvider.sol";

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 *               ______--------___
 *              /|             / |
 *   o___________|_\__________/__|
 *  ]|___     |  |=   ||  =|___  |"
 *  //   \\    |  |____||_///   \\|"
 * |  X  |\--------------/|  X  |\"
 *  \___/                  \___/
 * @title DIMO Credit
 * @custom:version 1.0.0
 * @author Sean Matt English (@smatthewenglish)
 * @custom:coauthor Lorran Sutter (@LorranSutter)
 * @custom:coauthor Dylan Moreland (@elffjs)
 * @custom:coauthor Allyson English (@aesdfghjkl666)
 * @custom:coauthor Yevgeny Khessin (@zer0stars)
 * @custom:coauthor Rob Solomon (@robmsolomon)
 * 
 * @dev non-transferable, ipso facto no approve logic
 * @notice approve this contract on $DIMO token before minting
 *         address is 0xE261D618a959aFfFd53168Cd07D12E37B26761db
 */
contract DimoCredit is AccessControl {

    /*//////////////////////////////////////////////////////////////
                             Access Controls
    //////////////////////////////////////////////////////////////*/
    
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant DC_ADMIN_ROLE = keccak256("DC_ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////
                              Member Variables
    //////////////////////////////////////////////////////////////*/
    
    uint256 public _dimoCreditRateInWei; 
    uint256 public _periodValidity;

    ///@dev receives proceeds from sale of credits
    address public _receiver; 

    IDimoToken public _dimo;
    NormalizedPriceProvider public _provider;

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/
    
    uint8 public immutable decimals;

    string public name;
    string public symbol;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf; 
    
    /*//////////////////////////////////////////////////////////////
                            Error Messages
    //////////////////////////////////////////////////////////////*/
    
    string INVALID_OPERATION = "DimoCredit: invalid operation";

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    ///@dev only used in mint and burn, not transferable
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event UpdateDimoCreditRate(uint256 rate);
    event UpdateDimoTokenAddress(address dimo_);
    event UpdateReceiverAddress(address receiver_);
    event UpdatePeriodValidity(uint256 periodValidity);
    event UpdatePriceProviderAddress(address provider);

    /**
     */
    constructor(address receiver_, address provider_) {
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        _dimo = IDimoToken(0xE261D618a959aFfFd53168Cd07D12E37B26761db);
        _provider = NormalizedPriceProvider(provider_);
        _periodValidity = 1 days;

        _receiver = receiver_;

        ///@dev 1 DC == $0.001 USD (1000000000000000)
        _dimoCreditRateInWei = 0.001 ether;
    
        decimals = 18;
        symbol = "DCX";
        name = "Dimo Credit";
    }

    /**
     * 
     */
    function mint(
        address to, 
        uint256 amountIn, 
        bytes calldata data
        ) external returns(uint256 dimoCredits) {
        (uint256 amountUsdPerTokenInWei,) = _provider.getAmountUsdPerToken(data);

        // Perform the multiplication
        uint256 usdAmountInWei = (amountIn * amountUsdPerTokenInWei);

        // Convert USD amount to data credits
        dimoCredits = (usdAmountInWei / _dimoCreditRateInWei);
        
        _mint(amountIn, dimoCredits, to);
    }

    function _mint(uint256 amountDimo, uint256 amountDataCredits, address to) private {
        
        _dimo.transferFrom(to, _receiver, amountDimo);

        totalSupply += amountDataCredits;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amountDataCredits;
        }

        emit Transfer(address(0), to, amountDataCredits);
    }

    /**
     * https://docs.openzeppelin.com/contracts/4.x/access-control
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                            NO-OP ERC20 Logic
    //////////////////////////////////////////////////////////////*/

    function transfer(address /*_to*/, uint256 /*_value*/) public view returns (bool /*success*/) {
        revert(INVALID_OPERATION);
    }

    function transferFrom(address /*_from*/, address /*_to*/, uint256 /*_value*/) public view returns (bool /*success*/) {
        revert(INVALID_OPERATION);
    }

    function approve(address /*_spender*/, uint256 /*_value*/) public view returns (bool /*success*/) {
        revert(INVALID_OPERATION);
    }

    function allowance(address /*_owner*/, address /*_spender*/) public view returns (uint256 /*remaining*/) {
        revert(INVALID_OPERATION);
    }

    /*//////////////////////////////////////////////////////////////
                          Admin Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev permissioned because it could cost $LINK to invoke
     */
    function updatePrice(bytes calldata data) external onlyRole(DC_ADMIN_ROLE) {
        (,uint256 updateTimestamp) = _provider.getAmountUsdPerToken(data);
        bool invalid = (block.timestamp - updateTimestamp) < _periodValidity;
        bool updatable = _provider.isUpdatable();
        
        if(invalid && updatable){
            _provider.updatePrice();
        }
    }

    function setDimoCreditRate(uint256 dimoCreditRateInWei_) external onlyRole(DC_ADMIN_ROLE) {
        _dimoCreditRateInWei = dimoCreditRateInWei_;
        emit UpdateDimoCreditRate(_dimoCreditRateInWei);
    }

    function setDimoTokenAddress(address dimoTokenAddress_) external onlyRole(DC_ADMIN_ROLE) {
        _dimo = IDimoToken(dimoTokenAddress_);
        emit UpdateDimoTokenAddress(dimoTokenAddress_);
    }

    function setPriceProviderAddress(address providerAddress_) external onlyRole(DC_ADMIN_ROLE) {
        _provider = NormalizedPriceProvider(providerAddress_);
        emit UpdatePriceProviderAddress(providerAddress_);
    }

    function setReceiverAddress(address receiver_) external onlyRole(DC_ADMIN_ROLE) {
        _receiver = receiver_;
        emit UpdateReceiverAddress(_receiver);
    }

    function setPeriodValidity(uint256 periodValidity_) external onlyRole(DC_ADMIN_ROLE) {
        _periodValidity = periodValidity_;
        emit UpdatePeriodValidity(_periodValidity);
    }

    /*//////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    function receiver() external view returns (address receiver_) {
        receiver_ = _receiver;
    }

    function dimoCreditRate() external view returns (uint256 dimoCreditRateInWei_) {
        dimoCreditRateInWei_ = _dimoCreditRateInWei;
    }

}