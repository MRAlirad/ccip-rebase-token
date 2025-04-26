// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
    * @title Rebase Token
    * @author Mohammadreza Alirad
    * @notice Implements a cross-chain ERC20 token where balances increase automatically over time.
    * @dev This contract uses a rebasing mechanism based on a per-second interest rate.
    * The global interest rate can only increase or stay the same. Each user gets assigned
    * the prevailing global interest rate upon their first interaction involving balance updates.
    * Balances are calculated dynamically in the `balanceOf` function.
*/
contract RebaseToken is ERC20 {
    //! Events !//
    event InterestRateSet(uint256 newInterestRate);

    //! ERRORS !//
    error RebaseToken__InterestRateCanOnlyIncrease(uint256 currentInterestRate, uint256 proposedInterestRate);

    uint256 constant private PRECISIO_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping (address => uint256) private s_userInterestRate;
    mapping (address => uint256) private s_userLastUpdatedTimestamp;

    constructor() ERC20("RebaseToken", "RBT") {}

    function setInterestRate(uint256 _newInterestRate) external {
        // Ensure the interest rate never decreases
        if (_newInterestRate < s_interestRate)
            revert RebaseToken__InterestRateCanOnlyIncrease(s_interestRate, _newInterestRate);

        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    function mint (address _to, uint256 _amount) external {
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }
    
    function burn (address _from, uint256 _amount) external {
        if(_amount == type(uint256).max) _amount = balanceOf(_from);

        _mintAccuredInterest(_from);
        _burn(_from, _amount);
    }

    function balanceOf (address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISIO_FACTOR;
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    function _mintAccuredInterest(address _user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);

        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;

        s_userLastUpdatedTimestamp[_user] = block.timestamp;

        _mint(_user, balanceIncrease);
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns(uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISIO_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }
}