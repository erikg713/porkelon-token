// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Porkelon is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public constant MAX_SUPPLY = 100_000_000_000 * 10**18; // 100 billion tokens with 18 decimals
    address public teamWallet; // Wallet for collecting 1% transaction fees

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _teamWallet) initializer public {
        __ERC20_init("Porkelon", "PORK");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        teamWallet = _teamWallet; // Set the team wallet for fees (replace with actual address when deploying)

        // Mint the entire max supply at initialization
        uint256 totalSupplyToMint = MAX_SUPPLY;

        // Allocations (replace placeholder addresses with actual wallet addresses)
        _mint(address(0xYourDevWalletAddressHere), (totalSupplyToMint * 25) / 100); // 25% to dev wallet (25B tokens)
        _mint(address(0xYourStakingRewardsWalletAddressHere), (totalSupplyToMint * 10) / 100); // 10% for staking and rewards (10B tokens)
        _mint(address(0xYourLiquidityWalletAddressHere), (totalSupplyToMint * 40) / 100); // 40% for liquidity lock (40B tokens)
        _mint(address(0xYourMarketingWalletAddressHere), (totalSupplyToMint * 10) / 100); // 10% for marketing and advertising (10B tokens)
        _mint(address(0xYourAirdropsWalletAddressHere), (totalSupplyToMint * 5) / 100); // 5% for airdrops (5B tokens)
        _mint(address(0xYourPresaleWalletAddressHere), (totalSupplyToMint * 10) / 100); // 10% for presale (10B tokens; handle presale separately)

        // Revoke minter role to prevent any further minting (supply is capped forever)
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender); // Removes ability to grant minter role again
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // No mint function exposed, as all supply is minted at init and role revoked

    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADER_ROLE) override {}

    // Override to apply 1% fee on transfers (not on mints/burns)
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        if (from != address(0) && to != address(0) && teamWallet != address(0)) { // Apply fee only on transfers
            uint256 fee = (value * 1) / 100; // 1% fee
            uint256 amountAfterFee = value - fee;
            super._update(from, teamWallet, fee); // Send fee to team wallet
            super._update(from, to, amountAfterFee); // Send remaining to recipient
        } else {
            super._update(from, to, value);
        }
    }

    // Optional: Function to update team wallet (only owner, for flexibility)
    function setTeamWallet(address newTeamWallet) public onlyOwner {
        require(newTeamWallet != address(0), "Invalid address");
        teamWallet = newTeamWallet;
    }
}
