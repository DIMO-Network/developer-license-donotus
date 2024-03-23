// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {DevLicenseCore} from "./DevLicenseCore.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/** 
 * https://dimo.zone/news/on-dimo-tokenomics
 */
contract DevLicenseStake is DevLicenseCore, ReentrancyGuard {

    /*//////////////////////////////////////////////////////////////
                              Member Variable
    //////////////////////////////////////////////////////////////*/
    
    uint256 public _stakeTotal;

    /*//////////////////////////////////////////////////////////////
                              Mappings
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => bool) public _frozen;
    mapping(uint256 => uint256) public _stakeLicense;

    /*//////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/

    event AssetFreezeUpdate(uint256 indexed tokenId, uint256 amount, bool frozen);
    event AssetForfeit(uint256 indexed tokenId, uint256 amount);
    event StakeDeposit(uint256 indexed tokenId, address indexed user, uint256 amount);
    event StakeWithdraw(uint256 indexed tokenId, address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            Error Messages
    //////////////////////////////////////////////////////////////*/

    string INVALID_PARAM = "DevLicenseDimo: invalid param";

    constructor(
        address receiver_,
        address licenseAccountFactory_,
        address provider_,
        address dimoTokenAddress_, 
        address dimoCreditAddress_,
        uint256 licenseCostInUsd_
    ) DevLicenseCore(receiver_, licenseAccountFactory_, provider_, dimoTokenAddress_, dimoCreditAddress_, licenseCostInUsd_) ReentrancyGuard() {}

    /*//////////////////////////////////////////////////////////////
                         Operative Functions
    //////////////////////////////////////////////////////////////*/

    /**
     */
    function lock(uint256 tokenId, uint256 amount) external {
        require(msg.sender == ownerOf(tokenId), INVALID_PARAM);

        _dimoToken.transferFrom(msg.sender, address(this), amount);

        _stakeLicense[tokenId] += amount;
        _stakeTotal += amount;

        emit StakeDeposit(tokenId, msg.sender, amount);
    }

    /**
     */
    function withdraw(uint256 tokenId, uint256 amount) public nonReentrant {
        require(amount > 0, INVALID_PARAM);
        require(msg.sender == ownerOf(tokenId), INVALID_PARAM);
        require(!_frozen[tokenId], "DevLicenseDimo: funds inaccessible");
        require(_stakeLicense[tokenId] >= amount, INVALID_PARAM);

        _transferOut(tokenId, amount);
        _dimoToken.transferFrom(address(this), msg.sender, amount);

        emit StakeWithdraw(tokenId, msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    function totalStaked() public view returns (uint256 totalStaked_) {
        totalStaked_ = _stakeTotal;
    }

    function licenseStaked(uint256 tokenId) public view returns (uint256 licenseStaked_) {
        licenseStaked_ = _stakeLicense[tokenId];
    }

    /*//////////////////////////////////////////////////////////////
                     Private Helper Function
    //////////////////////////////////////////////////////////////*/

    /**
     */
    function _transferOut(uint256 tokenId, uint256 amount) private {
        _stakeLicense[tokenId] -= amount;
        _stakeTotal -= amount;
    }

    /*//////////////////////////////////////////////////////////////
                            Admin Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice freeze assets in case of violation
     */
    function adminFreeze(uint256 tokenId, bool frozen) external onlyRole(LICENSE_ADMIN_ROLE) {
        _frozen[tokenId] = frozen;
        emit AssetFreezeUpdate(tokenId, _stakeLicense[tokenId], frozen);
    }

    /**
     * @notice forefeit assets in case of violation 
     */
    function adminBurnLockedFunds(uint256 tokenId, uint256 amount) external onlyRole(LICENSE_ADMIN_ROLE) {
        require(_stakeLicense[tokenId] >= amount, INVALID_PARAM);

        _transferOut(tokenId, amount);

        _dimoToken.burn(address(this), amount);
        emit AssetForfeit(tokenId, amount);
    }

    /**
     * @dev generalized admin transfer function
     */
    function adminReallocate(uint256 tokenId, uint256 amount, address to) external onlyRole(LICENSE_ADMIN_ROLE) {
        require(_stakeLicense[tokenId] <= amount, INVALID_PARAM);

        _transferOut(tokenId, amount);

        _dimoToken.transfer(to, amount);
        emit AssetForfeit(tokenId, amount);
    }

    /**
     * @dev in case funds get send to this contract as part of a donation attack, etc
     * only able to withdraw the difference btwn total lock, and balance of this contract.
     */
    function adminWithdraw(address to) external onlyRole(LICENSE_ADMIN_ROLE) {
        uint256 balaceOf = _dimoToken.balanceOf(address(this));
        uint256 amount = balaceOf - _stakeTotal;
        _dimoToken.transfer(to, amount);
    }

}
