// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IDimoCredit {
    function receiver() external view returns (address);
    function dimoCreditRate() external view returns (uint256);
    function burn(address from, uint256 amount) external;
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function mintAmountDc(
        address to, 
        uint256 dimoCredits,
        bytes calldata data) external returns(uint256 amountIn);
    function mint(
            address to, 
            uint256 amountIn,
            bytes calldata data
            ) external returns(uint256 dimoCredits);
    function grantRole(bytes32 role, address account) external;
}