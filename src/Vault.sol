// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IRebaseToken } from "./interfaces/IRebaseToken.sol";

contract Vault {
    //! Events !//
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    //! ERRORS !//
    error Vault_RedeemFailed();

    IRebaseToken private immutable i_rebaseToken;

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    function deposit() external payable {
        uint256 amountToMint = msg.value;

        if (amountToMint == 0) {
            revert("Deposit amount must be greater than zero");
        }

        i_rebaseToken.mint(msg.sender, amountToMint);

        emit Deposit(msg.sender, amountToMint);
    }

    function redeem(uint256 _amount) external {
        if (_amount == 0) {
            revert("Redeem amount must be greater than zero"); // Or use a custom error
        }

        i_rebaseToken.burn(msg.sender, _amount);

        (bool success, ) = payable(msg.sender).call{value: _amount}("");

        if (!success) {
            revert Vault_RedeemFailed();
        }

        emit Redeem(msg.sender, _amount);
    }

    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}