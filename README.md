# Cross Base Rebase Token

## Introduction to Building a Cross-Chain Rebase Token

Welcome to this section focused on constructing a sophisticated DeFi primitive: a cross-chain rebase token. We'll leverage the power of the Foundry development toolkit and Chainlink's Cross-Chain Interoperability Protocol (CCIP) to build, test, and deploy a token capable of operating across multiple blockchain networks while incorporating a dynamic supply mechanism.

This lesson tackles complex concepts, including advanced Solidity patterns, intricate cross-chain interactions facilitated by CCIP, and robust testing methodologies essential for secure and reliable smart contract development. We will explore how to design a token whose supply adjusts based on accrued interest and how to enable seamless transfers of this token between different blockchains.

### Core Concepts Explored

Before diving into the code, let's establish a clear understanding of the fundamental concepts underpinning this project:

1. **Cross-Chain Functionality:** This refers to the capability of smart contracts or digital assets, like our token, to interact or move between distinct blockchain networks. Our goal is to build a single token standard that can exist and be transferred across multiple chains.
2. **Rebase Token:** Unlike standard ERC20 tokens where a user's balance only changes via direct transfers, a rebase token features an automatically adjusting total supply. This adjustment, or "rebase," is typically driven by specific criteria. In our case, the supply will grow based on accrued linear interest. Consequently, a user's balance can increase over time simply by holding the token, reflecting their proportional share of the expanding total supply.
3. **Chainlink CCIP (Cross-Chain Interoperability Protocol):** This is the secure messaging and token transfer protocol we will utilize to enable the cross-chain capabilities of our rebase token. CCIP provides the infrastructure for sending messages and initiating token movements between supported networks.
4. **Foundry:** Our primary development environment. Foundry is a comprehensive toolkit for Solidity development, offering tools for compilation, deployment, and advanced testing strategies like fuzz testing and fork testing, which are crucial for this project's complexity.
5. **CCIP Token Pool:** A specific smart contract pattern used in conjunction with Chainlink CCIP for facilitating cross-chain token transfers. It manages the locking or burning of tokens on the source chain and the corresponding releasing or minting on the destination chain.
6. **Burn and Mint Mechanism:** The chosen strategy for cross-chain token transfers. When a user initiates a cross-chain transfer, their tokens are destroyed (burned) on the origin chain. Following confirmation via CCIP, an equivalent amount of new tokens is created (minted) for them on the destination chain, managed by the respective Token Pool contracts.
7. **Linear Interest:** The mechanism driving our token's rebase functionality. Interest accrues proportionally over time, causing the total supply (and thus individual balances, proportionally) to increase predictably.
8. **Vault Contract:** A user-facing smart contract that serves as the primary interaction point. Users can deposit a base asset (e.g., ETH) into the Vault, which then mints the corresponding amount of rebase tokens. Conversely, users can redeem their rebase tokens through the Vault, which burns the tokens and returns the underlying base asset. This contract effectively links the rebase token to the yield generated (represented by the rebase).
9. **Fork Testing:** A powerful testing technique provided by Foundry. It allows us to create a local copy of a live blockchain's state (e.g., Sepolia testnet). Tests can then interact with deployed contracts and real-world state in a controlled, local environment, enabling realistic end-to-end testing of cross-chain interactions without repeated testnet deployments.
10. **Precision and Truncation:** Inherent challenges when working with fixed-point arithmetic in Solidity, particularly for calculations involving rates and time, like our interest accrual. Careful implementation and specialized testing assertions are required to handle potential rounding errors or loss of precision.
11. **Token Dust:** Very small residual amounts of tokens that can sometimes result from complex calculations or distribution mechanisms. While often negligible, they may need consideration in contract logic or when writing precise test assertions.
12. **`super`** **Keyword (Solidity):** A keyword used within inheriting contracts to explicitly call functions defined in their parent contract(s). This is particularly relevant when overriding standard functions like `balanceOf` or `transfer`, allowing us to extend or modify the base functionality while still leveraging it.

### Project Code Structure and Implementation Details

The project repository contains several key components organized logically:

**`src/`** **Directory (Smart Contracts):**

-   **`RebaseToken.sol`:** This is the heart of our project – the custom ERC20-like token contract implementing the rebase logic.
    -   **Overridden Functions:** Key functions like `balanceOf` are overridden. Instead of returning a static value from a mapping, `balanceOf` dynamically calculates the user's current share.
    -   **`balanceOf(address _user)`** **Logic:** This function retrieves the user's last recorded principal balance (using `super.balanceOf(_user)` to access the underlying ERC20 storage) and then calculates the interest accrued since the user's last interaction or balance update. The final balance returned is the sum of the principal and the calculated accrued interest, adjusted for precision.
    -   **`_calculateUserAccumulatedInterestSinceLastUpdate(address _user)`:** An internal function responsible for computing the interest earned by a specific user based on their principal balance, their applicable interest rate (`s_userInterestRate[user]`), and the time elapsed (`block.timestamp - s_userLastUpdateTimestamp[user]`) since their balance was last updated. Precision factors (`PRECISION_FACTOR`) are used for fixed-point math.
    -   **`mint()`** **and** **`burn()`** **Functions:** These functions have unique considerations. Before executing the core minting or burning logic (often calling the parent's implementation via `super`), they must first trigger an update (`_mintAccruedInterest`) to account for any interest accrued up to the current block timestamp, ensuring calculations are based on the most up-to-date balances.
-   **`RebaseTokenPool.sol`:** This contract is a specialized version of a Chainlink CCIP Token Pool, specifically designed to handle our `RebaseToken`.
    -   **Inheritance:** It inherits from CCIP's base `TokenPool` contract.
    -   **Functionality:** Implements the `_lockOrBurn` and `_releaseOrMint` internal functions required by CCIP's burn-and-mint flow. On the source chain, it interacts with `RebaseToken.burn()`. On the destination chain, it interacts with `RebaseToken.mint()`, effectively managing the token's destruction and creation across chains as orchestrated by CCIP messages.
-   **`Vault.sol`:** The primary interface for users.
    -   **`deposit()`** **Function:** A `payable` function accepting the base asset (e.g., ETH). It calculates the equivalent amount of rebase tokens to issue based on the current state and calls `_rebaseToken.mint()` to credit the user.
    -   **`redeem()`** **Function:** Allows users to exchange their rebase tokens back for the base asset. It takes the amount of rebase tokens to redeem, calls `_rebaseToken.burn()` to destroy them, and then transfers the corresponding amount of the base asset back to the user.

**`script/`** **Directory (Foundry Scripts):**

-   Contains automation scripts written for Foundry's scripting capabilities.
-   **`Deployer.s.sol`:** Deploys the core contracts (`RebaseToken`, `Vault`, `RebaseTokenPool`) to the target chains.
-   **`ConfigurePools.s.sol`:** Configures the deployed `RebaseTokenPool` contracts on each chain, linking them together via CCIP settings.
-   **`BridgeTokens.s.sol`:** Executes a cross-chain token transfer using the configured CCIP setup and token pools.

**`test/`** **Directory (Foundry Tests):**

-   **`RebaseToken.t.sol`:** Contains unit tests and fuzz tests specifically for the `RebaseToken` contract.
    -   **Testing Focus:** Verifies the correctness of the rebase logic, interest accrual calculations, and overridden functions under various scenarios.
    -   **Handling Precision:** Likely employs assertions like `assertApproxEqAbs` (Assert Approximate Equals Absolute) to gracefully handle minor discrepancies that can arise from fixed-point arithmetic and time-dependent calculations during fuzzing, preventing failures due to insignificant "token dust."
-   **`CrossChain.t.sol`:** Contains integration tests focusing on the end-to-end cross-chain functionality.
    -   **Fork Testing:** Utilizes Foundry's fork testing (`vm.createSelectFork`) to simulate interactions on live testnet environments (like Sepolia) locally.
    -   **CCIP Simulation:** Leverages helper tools like `Chainlink Local` and `CCIPLocalSimulatorFork` to mimic the behavior of the CCIP network locally. This allows developers to test the full message-passing and token transfer flow (deposit -> bridge -> check balance on destination) without the delays and costs of constant testnet deployments.

**Automation (`bridgeToZkSync.sh`):**

-   A bash script is provided to demonstrate and automate the entire workflow:
    1. Deploying contracts to multiple chains (e.g., Sepolia and zkSync Sepolia).
    2. Configuring the CCIP lanes between the deployed token pools using Foundry scripts.
    3. Interacting with the `Vault` to deposit ETH and mint rebase tokens.
    4. Initiating and completing a cross-chain transfer using the `BridgeTokens.s.sol` script.
-   This showcases how scripting can orchestrate complex, multi-step, multi-chain operations efficiently.

### Key Takeaways and Learning Objectives

By working through this section, you will gain practical experience and understanding in:

-   Implementing Chainlink CCIP for cross-chain token transfers.
-   Adapting existing or custom tokens (like our rebase token) for use with CCIP.
-   Designing and coding a rebase token with time-based interest accrual.
-   Utilizing advanced Solidity features like the `super` keyword in inheritance hierarchies.
-   Mastering advanced Foundry testing techniques:
    -   Fuzz testing stateful contracts with time-dependent logic.
    -   Addressing precision issues in tests using approximate assertions.
    -   Setting up and executing fork tests for cross-chain scenarios.
    -   Employing local simulation tools like Chainlink Local for CCIP testing.
-   Applying cross-chain design patterns like burn-and-mint bridging.
-   Automating deployment and interaction workflows using bash and Foundry scripting.

Remember, the dynamic nature of rebase token balances and the complexities of cross-chain interactions necessitate rigorous testing. Fork testing and tools that simulate the cross-chain environment locally are invaluable for ensuring the correctness and security of such systems.

## Understanding Rebase Tokens: When Your Balance Changes Automatically

Have you ever looked at your crypto wallet and noticed your token balance changing even though you didn't buy or sell anything? This intriguing behavior is often the work of a special category of cryptocurrency known as a "Rebase Token." Let's delve into what these tokens are and how they function.

At its core, a rebase token is a type of cryptocurrency where the total circulating supply isn't fixed or changed only through typical minting/burning events. Instead, its supply adjusts automatically based on rules defined within its underlying smart contract algorithm. This mechanism is designed primarily to reflect changes in the token's underlying value or to distribute accrued rewards, such as interest earned in decentralized finance (DeFi) protocols.

The key difference between rebase tokens and standard cryptocurrencies lies in how they respond to value changes. With standard tokens (like Bitcoin or Ether), market forces primarily impact the _price_ per token, while the total supply remains relatively stable or changes predictably. Rebase tokens take a different approach: they adjust the _supply_ itself to reflect value shifts or earnings. This means the number of tokens held by each owner changes proportionally during a rebase event. Consequently, the price per token might be targeted to remain stable (in the case of certain stablecoins) or the change in supply directly represents the yield earned. These supply adjustments are formally known as "rebases."

There are broadly two main categories or use cases for rebase tokens:

1. **Rewards Rebase Tokens:** These are commonly found in DeFi protocols, especially lending and borrowing platforms. The token balance increases over time, representing the yield or interest earned by the holder. The rebase mechanism automatically distributes these earnings by increasing the number of tokens in each holder's wallet.
2. **Stable Value Tokens:** This type aims to maintain a stable price, often pegged to a fiat currency like the US dollar. The protocol's algorithm automatically increases or decreases the total token supply in response to market price fluctuations, attempting to push the price back towards its target peg. If the price is above the peg, supply increases (positive rebase) to reduce scarcity; if below the peg, supply decreases (negative rebase) to increase scarcity.

To understand the mechanics, consider a simple scenario. Imagine you hold 1000 tokens of a specific rebase cryptocurrency. The protocol initiates a "positive rebase" of 10%, perhaps to distribute interest earned across the network. After the rebase event completes, you would look in your wallet and find your balance automatically adjusted to 1100 tokens (your original 1000 plus 10% or 100 tokens).

Crucially, while your _number_ of tokens changes, your _percentage ownership_ of the total token supply remains exactly the same. This is because the rebase applies proportionally to _all_ token holders simultaneously. If your balance increased by 10%, the total circulating supply of the token also increased by 10%.

A prominent real-world example of rewards-based rebase tokens can be found in the Aave protocol, specifically its aTokens (like aUSDC, aDAI, aETH). When you deposit an asset, say USDC, into the Aave lending pool, you receive a corresponding amount of aTokens (aUSDC in this case) in return. These aTokens represent your claim on the deposited assets plus the interest they generate over time.

The magic happens through Aave's smart contracts. Unlike standard ERC-20 tokens where the `balanceOf` function typically returns a fixed value stored in the contract, the `balanceOf` function for Aave's aTokens (specifically in versions like Aave V2) is dynamic. When this function is called (e.g., by your wallet interface), it doesn't just retrieve a stored number. Instead, it _calculates_ your current balance on the fly. It takes your initial principal deposit (represented internally) and adds the interest that has accrued since your deposit or the last interaction. This calculation happens internally within the smart contract logic, often involving functions that determine the accrued interest based on the time elapsed and the prevailing interest rate. The value returned by `balanceOf` therefore increases steadily over time, reflecting your earned interest. This dynamic calculation _is_ the rebase mechanism in action for aTokens – your balance grows automatically without requiring separate transactions to claim interest.

Let's illustrate with Aave: Suppose you deposit 1000 USDC into Aave when the annual interest rate is 5%. After exactly one year, if you check your aUSDC balance, it will have automatically increased (rebased) to 1050 aUSDC, representing your initial deposit plus the 50 USDC earned in interest. You can then withdraw 1050 USDC by redeeming your 1050 aUSDC.

In conclusion, rebase tokens represent an innovative mechanism within the blockchain space, particularly relevant in DeFi applications like lending protocols. They allow for automatic supply adjustments to reflect value changes or distribute yield directly into holders' balances. Understanding how they work, especially the distinction between supply changes and price changes, and the proportional nature of rebases, is valuable for anyone navigating the evolving world of cryptocurrency and decentralized finance.

## Rebase Token-code-structure

### Introduction to Building a Rebase Token

This lesson guides you through the initial planning and setup for creating a rebase token. Our ultimate objective is to develop a _cross-chain_ rebase token utilizing Chainlink CCIP. However, to manage complexity and ensure clarity, we will begin by building a simpler, single-chain version. This foundational stage focuses on establishing the project environment and defining the core design principles that will govern our token's behavior.

### Setting Up Your Development Environment

Before writing any code, we need to set up our project structure using Foundry, a popular Solidity development toolkit, and Visual Studio Code as our editor.

1. **Create Project Directory:** Open your terminal and create a new directory for the project. You can name it descriptively; for this example, we'll use `cd `.

    ```bash
    mkdir ccip-rebase-token
    ```

2. **Navigate into Directory:** Change your current directory to the newly created one.

    ```bash
    cd ccip-rebase-token
    ```

3. **Initialize Foundry Project:** Use the Foundry command `forge init` to set up the basic project structure and install necessary dependencies like `forge-std`.

    ```bash
    forge init
    ```

4. **Open in VS Code:** Open the project folder in your code editor.

    ```bash
    code .
    ```

5. **Clean Up Default Files:** Foundry initializes the project with default example files (`Counter.sol`, `Counter.s.sol`, `Counter.t.sol`) in the `src`, `script`, and `test` directories respectively. We don't need these for our rebase token project, so delete them. Additionally, clear the contents of the default `README.md` file; we will populate it with our specific design notes.

### Core Rebase Token Design Principles

We'll define the fundamental requirements for our rebase token. These principles will guide the smart contract implementation.

1. **Protocol Deposit Mechanism:**

    - **Requirement:** "A protocol that allows user to deposit into a vault and in return, receive rebase tokens that represent their underlying balance".
    - **Implementation:** Users will interact with a `Vault` smart contract to deposit a base asset (e.g., ETH or an ERC20 stablecoin). In exchange for their deposit, the Vault will facilitate the minting of an equivalent amount of our `Rebase Token` to the user. These tokens signify the user's proportional claim on the assets held within the Vault, including any interest earned over time.

2. **Rebase Token Dynamic Balances:**
    - **Requirement:** "Rebase token -> `balanceOf` function is dynamic to show the changing balance with time."
    - **Clarification:** A user's token balance should appear to increase linearly based on the applicable interest rate.
    - **Interest Realization Mechanism:** This is a crucial design aspect. The standard `balanceOf` function in ERC20-like tokens is a `view` function, meaning it _cannot_ modify the blockchain's state (like minting new tokens). Directly minting tokens every time someone checks their balance would require transactions and be prohibitively expensive and impractical.
    - **Solution:** We differentiate between _conceptual interest accrual_ and _actual token minting_.
        - Interest _accrues_ mathematically over time based on the user's rate.
        - The `balanceOf` function will _calculate_ and return the user's current theoretical balance (initial principal + accrued interest), providing an up-to-date view without changing state.
        - The _actual minting_ of the accrued interest tokens to update the user's internal balance recorded on the blockchain only occurs when the user triggers a state-changing action. These actions include depositing more funds (minting), withdrawing funds (burning), transferring tokens, or, in the future cross-chain version, bridging tokens. The internal balance update happens _just before_ the primary action (deposit, transfer, etc.) is processed.

### Understanding the Interest Rate Mechanism

A unique interest rate system is central to this rebase token's design, aimed at rewarding early participants.

-   **Requirement:** "Interest rate".
-   **Mechanism Details:**
    -   "Individually set an interest rate for each user based on some global interest rate of the protocol at the time the user deposits into the vault."
    -   "This global interest rate can only decrease to incentivize/reward early adopters."
-   **Implementation:**
    -   A `globalInterestRate` exists for the entire protocol, controlled by an authorized role (e.g., owner).
    -   Crucially, the owner can _only decrease_ this `globalInterestRate` over time; it can never be increased.
    -   When a user makes their _first_ deposit into the Vault, the protocol reads the _current_ `globalInterestRate`.
    -   This rate is then stored as the user's personal `userInterestRate`.
    -   This `userInterestRate` remains fixed for the user from that point forward, associated with their deposited principal.
    -   **Example:**
        1. The `globalInterestRate` is initially set to 5% (0.05).
        2. User A deposits funds. Their `userInterestRate` is locked in at 5%.
        3. The protocol owner later decides to decrease the `globalInterestRate` to 4% (0.04) to moderate token emission or reflect changing market conditions.
        4. User B deposits funds _after_ the rate change. Their `userInterestRate` is locked in at the current global rate of 4%.
        5. User A continues to accrue interest at their original 5% rate, while User B accrues at 4%. If the owner lowers the rate again to 2%, both User A (5%) and User B (4%) retain their higher, previously locked rates.
    -   This design inherently rewards users who join and deposit earlier, as they secure potentially higher interest rates for the lifetime of their deposit compared to later participants.
    -   **Note on Yield Source:** While real-world rebase tokens often generate yield from underlying DeFi strategies (like staking, lending, or liquidity provision), the source of yield is abstracted in this initial implementation. Our primary focus here is on the tokenomics and mechanics of the rebase and interest rate system itself to encourage token adoption.

### Important Considerations

Keep these key points in mind as we move towards implementation:

-   **Incremental Development:** Starting with a single-chain version simplifies the initial development and testing process before introducing the complexities of cross-chain communication (CCIP).
-   **Complexity:** Rebase tokens are significantly more complex than standard ERC20 tokens due to their dynamic supply and balance calculations. Pay close attention to the implementation details.
-   **Interest Realization:** Clearly understanding the distinction between the calculated balance shown by `balanceOf` (conceptual accrual) and the actual updating of internal balances via minting during state-changing operations is critical.
-   **Early Adopter Incentive:** The decreasing global interest rate coupled with fixed user rates at the time of deposit is a deliberate design choice to incentivize early participation in the protocol.

### Next Steps

With the project environment set up and the core design principles defined, the next logical step is to begin writing the Solidity smart contract code for the `Rebase Token`, implementing the mechanisms discussed in this lesson.

## Building a Rebase Token: Initial Implementation in Solidity

This lesson guides you through the initial steps of creating a `RebaseToken.sol` smart contract using the Foundry framework and OpenZeppelin libraries. Our goal is to build a cross-chain ERC20 token where a user's balance automatically increases over time based on an accrued interest mechanism, without requiring explicit claiming transactions. We'll achieve this by inheriting from the standard OpenZeppelin `ERC20` contract and overriding key functions, notably `balanceOf`, to implement the dynamic rebasing logic.

### Core Concepts of the Rebase Token

Before diving into the code, let's understand the fundamental concepts:

1. **Rebase Token:** Unlike standard ERC20 tokens where `balanceOf` simply returns a stored value, a rebase token calculates the balance dynamically. It considers the user's initial principal amount (tokens originally minted or received) and adds the interest accrued since their last interaction with the contract. The balance effectively grows linearly over time.
2. **Interest Rate Mechanism:**
    - **Global Interest Rate (`s_interestRate`):** A single rate, defined per second, applicable to the entire contract. This rate is designed to only increase or stay the same, rewarding early participants.
    - **Personal Interest Rate (`s_userInterestRate`):** When a user first interacts (e.g., receives minted tokens), the _current_ global interest rate is captured and stored as their personal rate. This rate is used for calculating their specific accrued interest going forward.
    - **Last Update Timestamp (`s_userLastUpdatedAtTimestamp`):** To calculate interest accurately, the contract tracks the block timestamp of the last time each user's balance effectively changed or their interest was accounted for.
3. **Solidity Precision:** Solidity lacks native support for floating-point numbers. We handle calculations involving rates and balances using fixed-point arithmetic. This involves scaling numbers up by a large factor (typically `1e18` for 18 decimal places, matching the ERC20 standard) before performing calculations. We'll use a constant `PRECISION_FACTOR` (`1e18`) to represent the scaled value of `1`. Multiplication is performed before division to maintain precision.
4. **NatSpec Comments:** We will use Solidity Natural Language Specification (NatSpec) comments (`/** ... */`) extensively. These comments (`@title`, `@author`, `@notice`, `@dev`, `@param`, `@return`) improve code readability, enable automatic documentation generation, and can assist developer tools.

### Project Setup and Dependencies

We'll use the Foundry framework for development and testing.

1. **Create Contract File:** Create a new file named `RebaseToken.sol` within your Foundry project's `src` directory.
2. **Boilerplate:** Add the SPDX license identifier and the Solidity version pragma at the top of the file:
    ```solidity
    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.24;
    ```
3. **Install OpenZeppelin:** We need the battle-tested `ERC20` implementation from OpenZeppelin. Find the latest version tag (e.g., `v5.1.0`) on the OpenZeppelin Contracts GitHub repository. Install it using Foundry:
    ```bash
    forge install openzeppelin/openzeppelin-contracts@v5.1.0 --no-commit
    ```
    _Note: We use a specific version tag for stability and_ _`--no-commit`_ _if you have uncommitted changes in your repository._
4. **Configure Remappings:** Tell the Solidity compiler where to find the OpenZeppelin library by adding a remapping to your `foundry.toml` file:
    ```toml
    [profile.default]
    # ... other settings
    remappings = [
        "@openzeppelin/=lib/openzeppelin-contracts/"
    ]
    # ... other settings
    ```
5. **Import ERC20:** Import the necessary contract into `RebaseToken.sol`:
    ```solidity
    import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
    ```
6. **Verify Setup:** Run `forge build` in your terminal to ensure the import works and the project compiles.

### Contract Definition and State Variables

Now, let's define the contract structure, inherit from `ERC20`, and declare the necessary state variables.

```solidity
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
    // Represents 1 with 18 decimal places for fixed-point math
    uint256 private constant PRECISION_FACTOR = 1e18;

    // Global interest rate per second (scaled by PRECISION_FACTOR)
    // Example: 5e10 represents 0.00000005 or 0.000005% per second
    uint256 private s_interestRate = 5e10;

    // Maps users to their specific interest rate (set at interaction time)
    mapping(address => uint256) private s_userInterestRate;

    // Maps users to the block timestamp of their last balance update/interest accrual
    mapping(address => uint256) private s_userLastUpdatedAtTimestamp;

    // Constructor, Events, Errors, and Functions will follow...
}
```

-   We inherit from `ERC20` using the `is` keyword.
-   Contract-level NatSpec comments explain the purpose and high-level mechanics.
-   `PRECISION_FACTOR` is defined for our fixed-point calculations.
-   `s_interestRate` stores the global rate, initialized to a sample value.
-   Mappings `s_userInterestRate` and `s_userLastUpdatedAtTimestamp` store user-specific data.
-   The `s_` prefix denotes storage variables, and `private` visibility is used initially; we can add specific getters if needed later.

### Events and Custom Errors

Define events to log important state changes and custom errors for clear revert reasons.

```solidity
    // Inside the RebaseToken contract

    /**
     * @notice Emitted when the global interest rate is updated.
     * @param newInterestRate The new global interest rate per second (scaled).
     */
    event InterestRateSet(uint256 newInterestRate);

    /**
     * @notice Error reverted when attempting to set an interest rate lower than the current one.
     * @param currentInterestRate The current global interest rate (scaled).
     * @param proposedInterestRate The proposed new interest rate that was rejected (scaled).
     */
    error RebaseToken__InterestRateCanOnlyIncrease(uint256 currentInterestRate, uint256 proposedInterestRate);

    // Constructor, Functions will follow...
```

-   `InterestRateSet`: Signals a change in the global `s_interestRate`.
-   `RebaseToken__InterestRateCanOnlyIncrease`: Provides specific context if the interest rate update rule is violated. _Note: The summary mentioned a naming inconsistency (`CanOnlyDecrease`) which we've corrected here to reflect the logic (`CanOnlyIncrease`)._

### Constructor

The constructor initializes the underlying `ERC20` token with its name and symbol.

```solidity
    // Inside the RebaseToken contract

    /**
     * @notice Initializes the Rebase Token with a name and symbol.
     */
    constructor() ERC20("Rebase Token", "RBT") {}

    // Functions will follow...
```

### Core Functionality: Setting Rates, Minting, and Calculating Balances

Now, let's implement the core functions that define the rebase behavior.

**1. Setting the Global Interest Rate**

This function allows updating the global rate, enforcing the rule that it can only increase or stay the same.

```solidity
    /**
     * @notice Sets the global interest rate for the token contract.
     * @dev Reverts if the proposed rate is lower than the current rate.
     * Emits an {InterestRateSet} event on success.
     * @param _newInterestRate The desired new global interest rate per second (scaled by PRECISION_FACTOR).
     */
    function setInterestRate(uint256 _newInterestRate) external {
        // Ensure the interest rate never decreases
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyIncrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }
```

**2. Calculating Accumulated Interest Multiplier**

This internal helper function calculates the multiplier representing the interest growth since the user's last update.

```solidity
    /**
     * @notice Calculates the interest multiplier for a user since their last update.
     * @dev The multiplier represents (1 + (user_rate * time_elapsed)).
     * The result is scaled by PRECISION_FACTOR.
     * @param _user The address of the user.
     * @return linearInterest The calculated interest multiplier (scaled).
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256 linearInterest) {
        uint256 lastUpdateTimestamp = s_userLastUpdatedAtTimestamp[_user];
        // If never updated, assume current time to avoid huge elapsed time
        if (lastUpdateTimestamp == 0) {
            // Or alternatively, could set it during mint/transfer in initial setup
            lastUpdateTimestamp = block.timestamp;
        }

        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;

        // Calculate interest part: user_rate * time_elapsed (already scaled by 1e18 * seconds)
        uint256 interestPart = s_userInterestRate[_user] * timeElapsed;

        // Calculate multiplier: 1 + interest part
        // PRECISION_FACTOR represents 1 (scaled)
        linearInterest = PRECISION_FACTOR + interestPart;
        // Example: If rate is 10% per second (scaled) and 2 seconds pass:
        // interestPart = (0.1 * 1e18) * 2 = 0.2 * 1e18
        // linearInterest = 1e18 + 0.2 * 1e18 = 1.2 * 1e18 (representing a 1.2x multiplier)
    }
```

-   This function calculates `1 + (Rate * Time)` scaled by `PRECISION_FACTOR`.
-   It uses the user's specific rate (`s_userInterestRate`) and the time elapsed since `s_userLastUpdatedAtTimestamp`.
-   A check for `lastUpdateTimestamp == 0` handles the initial state before any updates.

**3. Overriding** **`balanceOf`**

This is the core of the rebase mechanism. We override the standard `balanceOf` to return the dynamic balance.

```solidity
    /**
     * @notice Gets the dynamic balance of an account, including accrued interest.
     * @dev Overrides the standard ERC20 balanceOf function.
     * Calculates balance as: Principal * (1 + (User Rate * Time Elapsed)).
     * Uses fixed-point math.
     * @param _user The address to query the balance for.
     * @return The calculated total balance (principal + accrued interest).
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // Get the stored principal balance (this is what _mint/_burn directly affects)
        // super.balanceOf() calls the original ERC20 implementation.
        uint256 principalBalance = super.balanceOf(_user);

        // If principal is zero, calculated balance is also zero
        if (principalBalance == 0) {
            return 0;
        }

        // Get the interest multiplier (scaled by 1e18)
        uint256 interestMultiplier = _calculateUserAccumulatedInterestSinceLastUpdate(_user);

        // Calculate final balance: (Principal * Multiplier) / PrecisionFactor
        // Principal is already scaled (implicitly by 1e18 as it's an ERC20 balance)
        // Multiplier is scaled by 1e18
        // Result of multiplication is scaled by 1e36
        // Divide by PRECISION_FACTOR (1e18) to get the final balance scaled by 1e18
        return (principalBalance * interestMultiplier) / PRECISION_FACTOR;
    }
```

-   We use `super.balanceOf(_user)` to fetch the underlying stored balance, which represents the principal.
-   We call `_calculateUserAccumulatedInterestSinceLastUpdate` to get the growth multiplier.
-   The crucial calculation `(principalBalance * interestMultiplier) / PRECISION_FACTOR` performs the multiplication first to preserve precision before dividing by `PRECISION_FACTOR` to bring the result back to the correct scale (18 decimals).

**4. Accruing Interest (Internal Helper)**

Before any action that changes the principal balance (like minting or transferring), we need to effectively "cash in" the accrued interest by minting it. This function also updates the user's last update timestamp.

```solidity
    /**
     * @notice Calculates accrued interest, mints it, and updates the user's last timestamp.
     * @dev This should be called *before* operations that rely on an up-to-date principal balance
     * or that modify the principal (e.g., mint, transfer, burn).
     * @param _user The address for which to accrue interest.
     */
    function _mintAccruedInterest(address _user) internal {
        uint256 principalBalance = super.balanceOf(_user);

        // Avoid calculations if principal is zero
        if (principalBalance == 0) {
            // Still update timestamp if they have a rate assigned, might receive tokens later
            if(s_userInterestRate[_user] > 0) {
                 s_userLastUpdatedAtTimestamp[_user] = block.timestamp;
            }
            return;
        }

        uint256 totalBalanceWithInterest = balanceOf(_user); // Use our overridden balanceOf

        // Interest to mint is the difference between the calculated total and the stored principal
        uint256 interestToMint = totalBalanceWithInterest - principalBalance;

        // Mint the accrued interest amount if there is any
        if (interestToMint > 0) {
            // _mint is the internal function from the parent ERC20 contract
            _mint(_user, interestToMint);
        }

        // Crucially, update the timestamp AFTER calculating and minting interest
        s_userLastUpdatedAtTimestamp[_user] = block.timestamp;
    }
```

-   This internal function first gets the principal using `super.balanceOf`.
-   It then calculates the _total_ balance (principal + interest) using our overridden `balanceOf`.
-   The difference is the interest that has accrued since the last update.
-   This interest amount is minted using the inherited `_mint` function.
-   Finally, and importantly, `s_userLastUpdatedAtTimestamp[_user]` is updated to `block.timestamp`.

**5. Minting New Tokens**

The public `mint` function allows creating new tokens. It must first account for any existing accrued interest before minting the new principal and setting the user's interest rate.

```solidity
    /**
     * @notice Mints new principal tokens to a user's account.
     * @dev Accrues existing interest first, then sets the user's interest rate
     * to the current global rate, and finally mints the new principal amount.
     * @param _to The recipient address.
     * @param _amount The amount of principal tokens to mint.
     */
    function mint(address _to, uint256 _amount) external {
        // 1. Calculate and mint any pending interest for the recipient FIRST
        _mintAccruedInterest(_to);

        // 2. Set (or update) the user's personal interest rate to the current global rate
        s_userInterestRate[_to] = s_interestRate;
        // Note: Timestamp is updated inside _mintAccruedInterest

        // 3. Mint the requested principal amount using the inherited internal function
        _mint(_to, _amount); // This updates the value returned by super.balanceOf()
    }
```

-   Calls `_mintAccruedInterest(_to)` to update the principal balance with accrued interest _before_ adding more.
-   Assigns the current `s_interestRate` to `s_userInterestRate[_to]`.
-   Calls the standard internal `_mint` function to increase the principal balance.

**6. Getter for User Interest Rate**

A simple view function to allow external checking of a user's assigned rate.

```solidity
    /**
     * @notice Gets the specific interest rate assigned to a user.
     * @param _user The address of the user.
     * @return The user's assigned interest rate per second (scaled).
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
} // End of RebaseToken contract
```

This completes the initial implementation of the `RebaseToken.sol` contract, covering state setup, rate management, and the core dynamic balance calculation via the overridden `balanceOf` function, along with the necessary logic in `mint` and `_mintAccruedInterest` to handle the rebasing correctly. Further development would involve implementing `transfer`, `transferFrom`, `burn`, and adding relevant tests.

## Mintinterest And-burn-functions

This lesson explores two essential functions within a rebase token smart contract: `_mintAccruedInterest` and `burn`. We'll delve into how to ensure users receive their earned interest correctly before their balance changes and how to handle token burning, particularly full withdrawals, using common DeFi patterns. This builds upon a standard ERC20 token structure, adding custom logic for linear interest accrual.

**Understanding Rebase Tokens and Balance Dynamics**

Before diving into the functions, let's recap key concepts:

* **Rebase Token:** A type of ERC20 token where a user's balance automatically increases over time based on a predefined mechanism, like interest accrual.

* **Principal Balance:** The amount of tokens explicitly minted or transferred to a user. This is the value stored in the base ERC20 `_balances` mapping (accessible via `super.balanceOf`).

* **Actual Balance:** The user's principal balance *plus* any interest that has accrued since their last balance update event (like a mint, burn, or transfer). Our contract calculates this on-the-fly using an overridden `balanceOf` function that factors in the time elapsed and the user's specific interest rate.

The core challenge is ensuring that the *principal balance* accurately reflects the *actual balance* before any operation that relies on or modifies this principal balance. This is where `_mintAccruedInterest` comes in.

**The** **`_mintAccruedInterest`** **Function: Synchronizing Balances**

The `_mintAccruedInterest` function is a crucial internal helper. Its sole purpose is to calculate any interest a user has earned since their last interaction and mint those tokens, effectively updating their principal balance to match their actual, interest-inclusive balance. It's marked `internal` because it's not intended for direct external calls but rather as a prerequisite step within other functions like `mint`, `burn`, and `transfer`.

**Implementation Steps:**

1. **Get Previous Principal Balance:** We first retrieve the user's balance as currently recorded by the standard ERC20 logic using `super.balanceOf(_user)`. This represents the tokens already minted to them.
2. **Get Current Actual Balance:** Next, we call our contract's *overridden* `balanceOf(_user)` function. This function performs the interest calculation, returning the principal plus newly accrued interest.
3. **Calculate Interest to Mint:** The difference between the `currentBalance` (actual) and the `previousPrincipleBalance` represents the interest (`balanceIncrease`) that has accrued and needs to be minted.
4. **Update Last Timestamp (Effect):** Critically, we update the user's last interaction timestamp (`s_userLastUpdatedTimestamp[_user] = block.timestamp;`). Following the **Checks-Effects-Interactions** pattern, we modify the contract's state *before* performing external calls or interactions (like minting) to prevent potential reentrancy issues.
5. **Mint the Interest (Interaction):** Finally, we call the internal `_mint(_user, balanceIncrease)` function inherited from OpenZeppelin's ERC20 contract. This issues the calculated `balanceIncrease` amount of tokens to the user, updating their principal balance in the `_balances` mapping. The `_mint` function itself emits the standard ERC20 `Transfer` event (from the zero address).

```solidity
/**
 * @notice Mint the accrued interest to the user since the last time they interacted with the protocol (e.g. burn, mint, transfer)
 * @param _user The user to mint the accrued interest to
 */
function _mintAccruedInterest(address _user) internal {
    // (1) find their current balance of rebase tokens that have been minted to the user -> principle balance
    uint256 previousPrincipleBalance = super.balanceOf(_user);
    // (2) calculate their current balance including any interest -> balanceOf
    uint256 currentBalance = balanceOf(_user);
    // calculate the number of tokens that need to be minted to the user -> (2) - (1)
    uint256 balanceIncrease = currentBalance - previousPrincipleBalance;

    // set the users last updated timestamp (Effect)
    s_userLastUpdatedTimestamp[_user] = block.timestamp;
    // mint the user the balance increase (Interaction)
    _mint(_user, balanceIncrease);
}
```

By calling `_mintAccruedInterest` at the beginning of any function that modifies a user's balance (like `mint` or `burn`), we ensure all calculations and actions are based on their fully realized, up-to-date token holdings.

**The** **`burn`** **Function: Handling Withdrawals and Redemptions**

The `burn` function allows users (or often, a managing contract like a vault) to destroy their tokens. This is typically used for withdrawals, redemptions, or potentially in cross-chain bridging mechanisms (burn-and-mint).

A key consideration here is handling "dust interest" – the small amount of interest that might accrue between when a user decides to withdraw their *entire* balance and when the transaction actually executes on-chain. To address this cleanly, we implement the "Max Uint Pattern".

**Implementation Steps:**

1. **Handle Max Uint Case:** We check if the requested `_amount` to burn is equal to `type(uint256).max`. This special value signals the user's intent to burn their entire balance. If detected, we ignore the provided `_amount` and instead fetch the user's *current actual balance* by calling `balanceOf(_from)`. This ensures that any dust interest accrued up to the moment of execution is included in the burn amount, allowing for a complete withdrawal.
2. **Mint Accrued Interest:** Before burning, we *must* call `_mintAccruedInterest(_from)`. This updates the user's principal balance to include any interest earned up to this point, ensuring the subsequent burn operation targets the correct, up-to-date principal amount.
3. **Burn Tokens:** We call the internal `_burn(_from, _amount)` function (inherited from OpenZeppelin ERC20). This decreases the user's principal balance by the specified `_amount` (which might have been updated in step 1) and emits the standard ERC20 `Transfer` event (to the zero address).

```solidity
/**
 * @notice Burn the user tokens when they withdraw from the vault
 * @param _from The user to burn the tokens from
 * @param _amount The amount of tokens to burn
 */
function burn(address _from, uint256 _amount) external { // Note: Access control should be added
    // Check if user wants to burn entire balance
    if (_amount == type(uint256).max) {
        // Update amount to current full balance including interest
        _amount = balanceOf(_from);
    }

    // Update balance with accrued interest first
    _mintAccruedInterest(_from);
    // Burn the specified (potentially updated) amount
    _burn(_from, _amount);
}
```

**Key Relationships and Considerations:**

* **Interdependency:** `burn` (and other state-changing functions like `mint`) rely heavily on `_mintAccruedInterest` to maintain balance integrity.

* **Timestamp Updates:** The `_mintAccruedInterest` function's update to `s_userLastUpdatedTimestamp` is vital for accurate future interest calculations performed by the overridden `balanceOf` function.

* **Event Emission:** We leverage the `Transfer` events emitted by the underlying `_mint` (within `_mintAccruedInterest`) and `_burn` (within `burn`) functions for off-chain tracking and indexing. No additional events are strictly necessary in these specific functions.

* **Max Uint Pattern:** Using `type(uint256).max` is a common and effective DeFi pattern for handling full balance operations, ensuring users can completely exit their positions without leaving dust behind. This pattern is seen in established protocols like Aave V3's aTokens.

* **Access Control:** As noted in the code comments, proper access control (e.g., using modifiers like `onlyOwner` or role-based access) should be added to functions like `burn` and `mint` to restrict who can call them, depending on the contract's specific requirements.

By implementing `_mintAccruedInterest` and `burn` as described, we create a robust rebase token system where user balances accurately reflect accrued interest, and withdrawals can be handled cleanly and completely.

## Finish Rebase-token-contract

This lesson focuses on completing our `RebaseToken` smart contract. We'll examine the standard functions provided by the OpenZeppelin ERC20 contract and determine how to adapt them for our specific needs. Our `RebaseToken` features an interest accrual mechanism, meaning a user's token balance effectively grows over time without explicit minting events. This requires careful consideration when implementing core ERC20 functionalities like transfers and balance checks.

### Understanding the Rebase Mechanism

The core challenge with our `RebaseToken` lies in the difference between a user's *principle balance* and their *effective balance*.

* **Principle Balance:** This represents the number of tokens explicitly minted to or received by a user through transfers. It's the amount directly tracked by the standard ERC20 `_balances` mapping.

* **Effective Balance:** This is the principle balance *plus* any interest that has accrued for the user since their last interaction with the contract (like a transfer or deposit).

Our contract needs to calculate and account for this accrued interest whenever an operation depends on an up-to-date balance. This interest accrues based on a global rate (`s_interestRate`) and potentially user-specific rates (`s_userInterestRate`).

### Adapting Standard ERC20 Functions

We inherit from OpenZeppelin's `ERC20.sol`. Let's review its public and external functions to see what needs modification:

* `name()`, `symbol()`: These return the token's name and symbol. No overrides are needed.

* `decimals()`: Returns the number of decimals (typically 18). While `virtual`, allowing overrides (like USDC's 6 decimals), we don't need to change it here.

* `allowance(address owner, address spender)`, `approve(address spender, uint256 value)`: Standard ERC20 approval mechanism. No overrides are needed. This functionality is crucial for interactions with other contracts or protocols, including potential cross-chain scenarios.

* Internal Functions (`_transfer`, `_update`, `_mint`, `_burn`, `_approve`, `_spendAllowance`): These handle the core logic for updating the `_balances` mapping and `_totalSupply`. Since they correctly manage the *principle* balances and supply, we don't need to override them directly. Our logic will hook into the public functions that call these internal ones.

Two key functions, `balanceOf` and `totalSupply`, require special attention.

### Overriding `balanceOf` for Accurate Balances

The standard `balanceOf(address account)` simply returns `_balances[account]`, which is only the *principle* balance. This is insufficient for our `RebaseToken` as it doesn't reflect the accrued interest.

Therefore, we must **override** **`balanceOf`**. The overridden function performs the following:

1. Retrieves the principle balance using `super.balanceOf(_user)`.
2. Calculates the interest accumulated for the user since their last balance update using an internal helper function (`_calculateUserAccumulatedInterestSinceLastUpdate`).
3. Combines the principle balance and the accumulated interest factor (adjusting for precision using `PRECISION_FACTOR`) to return the user's current *effective balance*.

The formula effectively becomes:
`Effective Balance = super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR`

This ensures that any external call checking a user's balance receives the accurate, up-to-date value including interest.

### The Challenge of `totalSupply` in Rebase Tokens

Similar to `balanceOf`, the standard `totalSupply()` function returns the value of `_totalSupply`. This variable is only updated during explicit `_mint` and `_burn` operations. It does *not* account for the interest implicitly accruing across *all* token holders.

Calculating the *true* effective total supply would require:

1. Iterating through every single token holder.
2. Calculating the current effective balance (including interest) for each holder.
3. Summing up these effective balances.

This approach presents significant problems:

* **High Gas Costs:** Iterating over potentially thousands or millions of holders is computationally expensive and would consume a large amount of gas.

* **Denial of Service (DoS) Risk:** If the number of holders grows too large, the transaction to calculate the total supply could exceed the block gas limit, making it impossible to execute.

**Decision:** Due to these risks, we will **not override** **`totalSupply`**. We accept the known limitation that `totalSupply()` in this contract will only represent the *principle* total supply (total tokens explicitly minted minus total tokens explicitly burned). It will *not* reflect the full effective supply including all accrued interest. This is a documented design trade-off prioritizing gas efficiency and contract robustness over perfect total supply representation.

### Implementing the `transfer` Override

The standard `transfer` function only moves principle tokens. We need to override it to handle interest accrual and rate inheritance correctly.

Our overridden `transfer(address _recipient, uint256 _amount)` performs these steps:

1. **Mint Accrued Interest:** Before the transfer occurs, call `_mintAccruedInterest(msg.sender)` to update the sender's principle balance with their accrued interest.
2. **Mint Recipient Interest:** Similarly, call `_mintAccruedInterest(_recipient)` to update the recipient's principle balance.
3. **Handle Max Amount:** Check if `_amount` is `type(uint256).max`. If so, set `_amount` to the sender's *effective* balance (`balanceOf(msg.sender)`).
4. **Interest Rate Inheritance:** This is crucial. Check if the recipient had a zero balance *before* this transfer might have started accruing interest for them (ideally check principle balance or if `s_userInterestRate[_recipient]` was zero before step 2). If the recipient is effectively new (`balanceOf(_recipient) == 0` *after* their interest minting in the current implementation), set their interest rate `s_userInterestRate[_recipient]` to match the sender's rate `s_userInterestRate[msg.sender]`. This ensures new holders inherit a rate, preventing them from gaining interest without prior interaction. If the recipient already held tokens, their existing rate remains unchanged, preventing potential manipulation where someone sends dust to lower another user's rate.
5. **Execute Transfer:** Call `super.transfer(_recipient, _amount)` to perform the standard ERC20 transfer of the principle amount using the updated balances.
6. **Return Result:** Return the boolean success value from `super.transfer`.

### Implementing the `transferFrom` Override

Similar to `transfer`, `transferFrom` needs overriding to handle interest. The logic mirrors the `transfer` override closely.

Our overridden `transferFrom(address _sender, address _recipient, uint256 _amount)` does the following:

1. **Mint Accrued Interest:** Call `_mintAccruedInterest(_sender)`.
2. **Mint Recipient Interest:** Call `_mintAccruedInterest(_recipient)`.
3. **Handle Max Amount:** Check for `type(uint256).max`. Note: The reference implementation sets `_amount = balanceOf(_sender)` here. Be aware this differs from standard `transferFrom`, which typically depends on the spender's allowance, not the sender's total balance. This might be a specific design choice or simplification.
4. **Interest Rate Inheritance:** Check if the recipient is new (`balanceOf(_recipient) == 0` after interest minting) and set their interest rate `s_userInterestRate[_recipient]` from the `_sender`'s rate (`s_userInterestRate[_sender]`) if necessary. The rationale is the same as in `transfer`.
5. **Execute Transfer:** Call `super.transferFrom(_sender, _recipient, _amount)`. This function handles the necessary allowance checks and executes the principle token transfer.
6. **Return Result:** Return the boolean success value from `super.transferFrom`.

### Adding Utility Getter Functions

To provide transparency and access to underlying data, we add some helpful getter functions:

* `principleBalanceOf(address _user) external view returns (uint256)`:

  * **Purpose:** Allows anyone to query a user's balance *without* the accrued interest component. This is useful for understanding the base amount explicitly held.

  * **Implementation:** Simply returns `super.balanceOf(_user)`.

* `getInterestRate() external view returns (uint256)`:

  * **Purpose:** Provides read-only access to the current *global* interest rate (`s_interestRate`), as the state variable itself is private. New depositors typically receive this rate.

  * **Implementation:** Returns `s_interestRate`.

* `getUserInterestRate(address _user) external view returns (uint256)`:

  * **Purpose:** Allows querying the specific interest rate assigned to an individual user (`s_userInterestRate[_user]`), as the mapping is private.

  * **Implementation:** Returns `s_userInterestRate[_user]`.

**Note on Rate Consolidation:** Be mindful of scenarios where a user consolidates tokens from multiple addresses they control, potentially with different interest rates. The current transfer logic assigns the sender's rate only if the recipient was new. Consolidating funds into an existing address will not change that address's established interest rate. This behavior should be clearly documented.

### Critical Next Step: Access Control

We have now implemented the core ERC20 logic adapted for our rebase mechanism. However, there is a **major security vulnerability**: functions like `_mint`, `_burn` (if made public/external), and any administrative functions like `setInterestRate` currently lack access control. This means *anyone* could potentially call them, allowing unauthorized minting, burning, or rate manipulation.

The immediate next step is to implement robust access control, typically using modifiers like `onlyOwner` (from OpenZeppelin's `Ownable.sol`) or more complex role-based access systems, to restrict sensitive functions to authorized addresses only. **This is crucial before deploying the contract.**

### Conclusion

We have successfully integrated and adapted standard ERC20 functionality for our `RebaseToken`. Key adaptations included overriding `balanceOf`, `transfer`, and `transferFrom` to account for interest accrual and manage interest rate inheritance for new recipients. We made a conscious design decision to leave `totalSupply` representing only the principle supply due to gas and security concerns. Finally, we added essential getter functions for transparency and highlighted the critical, non-negotiable need to implement access control in the next phase.
