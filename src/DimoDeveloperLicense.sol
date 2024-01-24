// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ILicenseAccountFactory} from "./interface/ILicenseAccountFactory.sol";
import {IDimoDeveloperLicense} from "./interface/IDimoDeveloperLicense.sol";
import {IDimoToken} from "./interface/IDimoToken.sol";
import {IDimoDeveloperLicenseAccount} from "./interface/IDimoDeveloperLicenseAccount.sol";

contract DimoDeveloperLicense is ERC721, IDimoDeveloperLicense {

    ILicenseAccountFactory public _laf;

    uint256 public licenseCost;
    uint256 private counter;
    IDimoToken private dimoToken;

    event LicenseMinted(uint256 indexed tokenId, address indexed owner, address indexed account, string clientId);
    event RedirectUriEnabled(uint256 indexed tokenId, string uri);
    event SignerEnabled(uint256 indexed tokenId, address indexed signer);

    error ClientIdTaken();
    error Unauthorized();

    mapping(uint256 => address) private accounts;
    mapping(uint256 => mapping(string => bool)) private redirectUris;
    mapping(uint256 => mapping(address => bool)) private signers;

    mapping(uint256 => string) tokenIdToClientId;
    mapping(string => uint256) clientIdToTokenId;

    constructor(
        address laf_,
        address dimoTokenAddress, 
        uint256 licenseCost_) ERC721("DIMO Developer License", "DDL") {
        
        _laf = ILicenseAccountFactory(laf_);
        _laf.setLicense(address(this));
        dimoToken = IDimoToken(dimoTokenAddress);
        licenseCost = licenseCost_;
    }

    function mint(string calldata clientId) public returns (uint256, address) {
        if (clientIdToTokenId[clientId] != 0) {
            revert ClientIdTaken();
        }

        dimoToken.transferFrom(msg.sender, address(this), licenseCost);

        uint256 tokenId = ++counter;
        tokenIdToClientId[tokenId] = clientId;
        clientIdToTokenId[clientId] = tokenId;
        _mint(msg.sender, tokenId);

        address accountAddress = _laf.create(tokenId);

        emit LicenseMinted(tokenId, msg.sender, accountAddress, clientId);

        return (tokenId, accountAddress);
    }

    function enableRedirectUri(uint256 tokenId, string calldata uri) public {
        if (msg.sender != ownerOf(tokenId)) {
            revert Unauthorized();
        }

        redirectUris[tokenId][uri] = true;

        emit RedirectUriEnabled(tokenId, uri);
    }

    function enableSigner(uint256 tokenId, address signer) public {
        if (msg.sender != ownerOf(tokenId)) {
            revert Unauthorized();
        }

        signers[tokenId][signer] = true;
        emit SignerEnabled(tokenId, signer);
    }

    function isSigner(uint256 tokenId, address signer) public view returns (bool) {
        return signers[tokenId][signer];
    }
}