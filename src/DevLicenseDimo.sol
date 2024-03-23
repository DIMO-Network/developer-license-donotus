// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IDimoCredit} from "./interface/IDimoCredit.sol";
import {IDimoToken} from "./interface/IDimoToken.sol";
import {DevLicenseMeta} from "./DevLicenseMeta.sol";
import {DevLicenseCore} from "./DevLicenseCore.sol";

/**
 *                    _..-------++._
 *                _.-'/ |      _||  \"--._
 *          __.--'`._/_\j_____/_||___\    `----.
 *     _.--'_____    |          \     _____    /
 *  _j    /,---.\   |        =o |   /,---.\   |_
 * [__]==// .-. \\==`===========/==// .-. \\=[__]
 *   `-._|\ `-' /|___\_________/___|\ `-' /|_.'
 *         `---'                     `---'
 * @title DIMO Developer License
 * @custom:version 1.0.0
 * @author Sean Matt English (@smatthewenglish)
 * @custom:coauthor Lorran Sutter (@LorranSutter)
 * @custom:coauthor Dylan Moreland (@elffjs)
 * @custom:coauthor Yevgeny Khessin (@zer0stars)
 * @custom:coauthor Rob Solomon (@robmsolomon)
 * @custom:contributor Allyson English (@aesdfghjkl666)
 * @custom:contributor James Li (@ilsemaj)
 */
contract DevLicenseDimo is DevLicenseMeta {

    /*//////////////////////////////////////////////////////////////
                             Access Controls
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant REVOKER_ROLE = keccak256("REVOKER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            Member Variables
    //////////////////////////////////////////////////////////////*/

    string public name;
    string public symbol;

    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event RedirectUriEnabled(uint256 indexed tokenId, string uri);
    event RedirectUriDisabled(uint256 indexed tokenId, string uri); 
    event Issued(uint256 indexed tokenId, address indexed owner, address indexed clientId);

    /*//////////////////////////////////////////////////////////////
                               Mappings
    //////////////////////////////////////////////////////////////*/
    
    mapping(uint256 => mapping(string => bool)) private _redirectUris;

    constructor(
        address receiver_,
        address licenseAccountFactory_,
        address provider_,
        address dimoTokenAddress_, 
        address dimoCreditAddress_,
        uint256 licenseCostInUsd_) 
    DevLicenseMeta(
        receiver_,
        licenseAccountFactory_,
        provider_,
        dimoTokenAddress_, 
        dimoCreditAddress_,
        licenseCostInUsd_
    ) {
        symbol = "DLX";
        name = "DIMO Developer License";
    }

    /*//////////////////////////////////////////////////////////////
                            Redirect URI
    //////////////////////////////////////////////////////////////*/

    function redirectUriStatus(uint256 tokenId, string calldata uri) external view returns (bool enabled) {
        enabled = _redirectUris[tokenId][uri];
    }

    /**
     */
    function setRedirectUri(
            uint256 tokenId, 
            bool enabled, 
            string calldata uri
        ) onlyTokenOwner(tokenId) external {
            if(enabled) {
                emit RedirectUriEnabled(tokenId, uri);
            } else {
                emit RedirectUriDisabled(tokenId, uri);
            }
        _redirectUris[tokenId][uri] = enabled;
    }

    function removeRedirectUri(uint256 tokenId, string calldata uri) onlyTokenOwner(tokenId) external {
        delete _redirectUris[tokenId][uri];
        emit RedirectUriDisabled(tokenId, uri);
    }

    /*//////////////////////////////////////////////////////////////
                            License Logic
    //////////////////////////////////////////////////////////////*/

    function issueInDimo() external returns (uint256 tokenId, address clientId) {
        return issueInDimo(msg.sender);
    }

    /**
     * @dev transfer spent $DIMO to the DimoCredit receiver
     */
    function issueInDimo(address to) public returns (uint256 tokenId, address clientId) {
        
        (uint256 amountUsdPerToken,) = _provider.getAmountUsdPerToken();
        
        uint256 tokenTransferAmount = (_licenseCostInUsd1e18 / amountUsdPerToken) * 1 ether;
        
        _dimoToken.transferFrom(to, _receiver, tokenTransferAmount);

        return _issue(to);
    }

    function issueInDc() external returns (uint256 tokenId, address clientId) {
        return issueInDc(msg.sender);
    }

    /**
     */
    function issueInDc(address to) public returns (uint256 tokenId, address clientId) {
        uint256 dcTransferAmount = (_licenseCostInUsd1e18 / _dimoCredit.dimoCreditRate()) * 1 ether;
        _dimoCredit.burn(to, dcTransferAmount);

        return _issue(to);
    }

    /**
     * @notice clientId is the DimoDeveloperLicenseAccount that holds the token
     */
    function _issue(address to) private returns (uint256 tokenId, address clientId) {
        tokenId = ++_counter;
        clientId = _licenseAccountFactory.create(tokenId);

        _tokenIdToClientId[tokenId] = clientId;
        _clientIdToTokenId[clientId] = tokenId;
        _ownerOf[tokenId] = to;

        emit Issued(tokenId, to, clientId);
        emit Locked(tokenId); ///@dev ERC5192
        emit Transfer(address(0), to, tokenId); ///@dev ERC721
    }

    /**
     * @notice only admin enabled addresses are allowed to revoke/burn licenses
     */
    function revoke(uint256 tokenId) external onlyRole(REVOKER_ROLE) {
        require(_stakeLicense[tokenId] == 0, "DevLicenseDimo: resolve staked funds prior to revocation");

        address tokenOwner = _ownerOf[tokenId];
        delete _ownerOf[tokenId];
        
        address clientId = _tokenIdToClientId[tokenId];
        delete _tokenIdToClientId[tokenId];
        delete _clientIdToTokenId[clientId];

        emit Transfer(tokenOwner, address(0), tokenId); ///@dev ERC721
    }

}
