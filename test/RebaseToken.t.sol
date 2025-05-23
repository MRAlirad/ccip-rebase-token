// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24; // Ensure this matches or is compatible with your contracts

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interface/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);

        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));

        rebaseToken.grantMintAndBurnRole(address(vault));

        (bool success,) = payable(address(vault)).call{value: 1 ether}("");

        vm.stopPrank();
    }
    
    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);

        vm.deal(user, amount);


        vm.stopPrank(); // Stop acting as 'user'
    }
}