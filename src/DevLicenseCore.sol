// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {NormalizedPriceProvider} from "./provider/NormalizedPriceProvider.sol";
import {ILicenseAccountFactory} from "./interface/ILicenseAccountFactory.sol";
import {IDevLicenseDimo} from "./interface/IDevLicenseDimo.sol";
import {IDimoCredit} from "./interface/IDimoCredit.sol";
import {IDimoToken} from "./interface/IDimoToken.sol";

contract DevLicenseCore is IDevLicenseDimo, AccessControl {

    /*//////////////////////////////////////////////////////////////
                             Access Controls
    //////////////////////////////////////////////////////////////*/
    
    bytes32 public constant LICENSE_ADMIN_ROLE = keccak256("LICENSE_ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////
                              Member Variables
    //////////////////////////////////////////////////////////////*/
    
    IDimoToken public _dimoToken; 
    IDimoCredit public _dimoCredit;
    NormalizedPriceProvider public _provider;
    ILicenseAccountFactory public _licenseAccountFactory;
    
    ///@dev signer validity expiration
    uint256 public _periodValidity; 
    uint256 public _licenseCostInUsd1e18;
    uint256 public _counter;
    ///@dev receives proceeds from sale of license
    address public _receiver;

    /*//////////////////////////////////////////////////////////////
                              Mappings
    //////////////////////////////////////////////////////////////*/
    
    mapping(uint256 => address) public _ownerOf;
    mapping(uint256 => address) public _tokenIdToClientId;
    mapping(address => uint256) public _clientIdToTokenId;
    
    ///@dev expiration determined by block.timestamp
    mapping(uint256 => mapping(address => uint256)) public _signers; 

    /*//////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/
    
    ///@dev on mint & burn
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId); 
    event SignerEnabled(uint256 indexed tokenId, address indexed signer);
    event Locked(uint256 indexed tokenId);

    event UpdateLicenseCost(uint256 licenseCost);
    event UpdateReceiverAddress(address receiver_);
    event UpdateDimoTokenAddress(address dimoToken_);
    event UpdatePeriodValidity(uint256 periodValidity);
    event UpdatePriceProviderAddress(address provider);
    event UpdateDimoCreditAddress(address dimoCredit_);
    event UpdateLicenseAccountFactoryAddress(address licenseAccountFactory_);

    /*//////////////////////////////////////////////////////////////
                            Error Messages
    //////////////////////////////////////////////////////////////*/
    
    string INVALID_TOKEN_ID = "DevLicenseDimo: invalid tokenId";
    string INVALID_OPERATION = "DevLicenseDimo: invalid operation";
    string INVALID_MSG_SENDER = "DevLicenseDimo: invalid msg.sender";

    /*//////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/

    modifier onlyTokenOwner(uint256 tokenId) { 
        require(msg.sender == ownerOf(tokenId), INVALID_MSG_SENDER);
        _;
    }

    constructor(
        address receiver_,
        address licenseAccountFactory_,
        address provider_,
        address dimoTokenAddress_, 
        address dimoCreditAddress_,
        uint256 licenseCostInUsd1e18_) {

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        _periodValidity = 365 days;

        _receiver = receiver_;

        _dimoCredit = IDimoCredit(dimoCreditAddress_);
        _provider = NormalizedPriceProvider(provider_);
    
        _licenseAccountFactory = ILicenseAccountFactory(licenseAccountFactory_);
        _dimoToken = IDimoToken(dimoTokenAddress_);
        _licenseCostInUsd1e18 = licenseCostInUsd1e18_;

        emit UpdatePeriodValidity(_periodValidity);
        emit UpdateLicenseCost(_licenseCostInUsd1e18);
    }

    /*//////////////////////////////////////////////////////////////
                       Signer a.k.a. API Key
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice License can be minted by any EOA and assigned an owner, 
     * or by the owner directly. the owner then enables a key and/or set
     * of keys to act as a signer, to sign challenges from the backend 
     * to access API resources.
     */
    function enableSigner(uint256 tokenId, address signer) onlyTokenOwner(tokenId) external {
        _enableSigner(tokenId, signer);
    }

    function _enableSigner(uint256 tokenId, address signer) internal {
        _signers[tokenId][signer] = block.timestamp;
        emit SignerEnabled(tokenId, signer);
    }

    function isSigner(uint256 tokenId, address signer) public view returns (bool) {
        uint256 timestampInit = _signers[tokenId][signer];
        uint256 timestampCurrent = block.timestamp;
        if(timestampCurrent - timestampInit > _periodValidity) {
            return false;
        } else {
            return true;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            Admin Functions
    //////////////////////////////////////////////////////////////*/

    function setReceiverAddress(address receiver_) external onlyRole(LICENSE_ADMIN_ROLE) {
        _receiver = receiver_;
        emit UpdateReceiverAddress(_receiver);
    }

    function setLicenseCost(uint256 licenseCostInUsd1e18_) external onlyRole(LICENSE_ADMIN_ROLE) {
        _licenseCostInUsd1e18 = licenseCostInUsd1e18_;
        emit UpdateLicenseCost(_licenseCostInUsd1e18);
    }

    function setPeriodValidity(uint256 periodValidity_) external onlyRole(LICENSE_ADMIN_ROLE) {
        _periodValidity = periodValidity_;
        emit UpdatePeriodValidity(_periodValidity);
    }

    function setPriceProviderAddress(address providerAddress_) external onlyRole(LICENSE_ADMIN_ROLE) {
        _provider = NormalizedPriceProvider(providerAddress_);
        emit UpdatePriceProviderAddress(providerAddress_);
    }

    function setDimoCreditAddress(address dimoCreditAddress_) external onlyRole(LICENSE_ADMIN_ROLE) {
        _dimoCredit = IDimoCredit(dimoCreditAddress_);
        emit UpdateDimoCreditAddress(dimoCreditAddress_);
    }

    function setDimoTokenAddress(address dimoTokenAddress_) external onlyRole(LICENSE_ADMIN_ROLE) {
        _dimoToken = IDimoToken(dimoTokenAddress_);
        emit UpdateDimoTokenAddress(dimoTokenAddress_);
    }
    
    function setLicenseFactoryAddress(address licenseAccountFactory_) external onlyRole(LICENSE_ADMIN_ROLE) {
        _licenseAccountFactory = ILicenseAccountFactory(licenseAccountFactory_);
        emit UpdateLicenseAccountFactoryAddress(licenseAccountFactory_);
    }

    /*//////////////////////////////////////////////////////////////
                             NO-OP NFT Logic
    //////////////////////////////////////////////////////////////*/

    function approve(address /*spender*/, uint256 /*id*/) public virtual {
        revert(INVALID_OPERATION);
    }

    function setApprovalForAll(address /*operator*/, bool /*approved*/) public virtual {
        revert(INVALID_OPERATION);
    }

    function transferFrom(address /*from*/, address /*to*/, uint256 /*id*/) public virtual {
        revert(INVALID_OPERATION);
    }

    function safeTransferFrom(
        address /*from*/,
        address /*to*/,
        uint256 /*id*/
    ) public virtual {
        revert(INVALID_OPERATION);
    }

    function safeTransferFrom(
        address /*from*/,
        address /*to*/,
        uint256 /*id*/,
        bytes memory /*data*/
    ) public virtual {
        revert(INVALID_OPERATION);
    }

    /*//////////////////////////////////////////////////////////////
                              NFT Logic
    //////////////////////////////////////////////////////////////*/

    function totalSupply() external view returns (uint256 totalSupply_) {
        totalSupply_ = _counter;
    } 

    function ownerOf(uint256 tokenId) public view virtual returns (address owner) {
        require((owner = _ownerOf[tokenId]) != address(0), INVALID_TOKEN_ID);
    }

    /*//////////////////////////////////////////////////////////////
                            SBT Logic
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev ERC5192: Minimal Soulbound NFTs Minimal interface for 
     * soulbinding EIP-721 NFTs
     */
    function locked(uint256 tokenId) external view returns (bool locked_) {
        require(locked_ = _exists(tokenId), INVALID_TOKEN_ID);
    }

    /*//////////////////////////////////////////////////////////////
                         Private Helper Functions
    //////////////////////////////////////////////////////////////*/

    function _exists(uint256 tokenId) private view returns (bool) {
        return _ownerOf[tokenId] != address(0);
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/
    
    function supportsInterface(bytes4 interfaceId) public override pure returns (bool) {
        return
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0xb45a3c0e || // ERC165 Interface ID for ERC5192
            interfaceId == 0x5b5e139f;   // ERC165 Interface ID for ERC721Metadata
    }

}
