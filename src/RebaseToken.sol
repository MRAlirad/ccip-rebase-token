// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
    * @title Rebase Token
    * @author Mohammadreza Alirad
    * @notice Implements a cross-chain ERC20 token where balances increase automatically over time.
    * @dev This contract uses a rebasing mechanism based on a per-second interest rate.
    * The global interest rate can only increase or stay the same. Each user gets assigned
    * the prevailing global interest rate upon their first interaction involving balance updates.
    * Balances are calculated dynamically in the `balanceOf` function.
*/
contract RebaseToken is ERC20, Ownable, AccessControl {
    //! Events !//
    event InterestRateSet(uint256 newInterestRate);

    //! ERRORS !//
    error RebaseToken__InterestRateCanOnlyIncrease(uint256 currentInterestRate, uint256 proposedInterestRate);

    uint256 private constant PRECISIO_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = 5e10;
    mapping (address => uint256) private s_userInterestRate;
    mapping (address => uint256) private s_userLastUpdatedTimestamp;

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}
    
    function grantMintAndBurnRole (address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // Ensure the interest rate never decreases
        if (_newInterestRate < s_interestRate)
            revert RebaseToken__InterestRateCanOnlyIncrease(s_interestRate, _newInterestRate);

        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }
    
    function principleBalanceOf (address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    function mint (address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function burn (address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if(_amount == type(uint256).max) _amount = balanceOf(_from);

        _mintAccuredInterest(_from);
        _burn(_from, _amount);
    }

    function balanceOf (address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISIO_FACTOR;
    }

    function transfer (address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(msg.sender);
        _mintAccuredInterest(_recipient);

        if(_amount == type(uint256).max) _amount = balanceOf(msg.sender);

        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);
    }
    
    function transferFrom (address _sender, address _recipient, address _amount) public override returns (bool) {
        _mintAccuredInterest(_sender);
        _mintAccuredInterest(_recipient);

        if(_amount == type(uint256).max) _amount = balanceOf(_sender);

        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }

        return super.transferFrom(_sender, _recipient, _amount);
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
    
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns(uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISIO_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }
}