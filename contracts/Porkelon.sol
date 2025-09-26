// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title Porkelon
 * @dev Upgradeable ERC20 token on Polygon with burnable, pausable, and 1% transfer fee features.
 *      Uses UUPS proxy and role-based access control.
 */
contract Porkelon is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public teamWallet;
    uint256 public constant MAX_SUPPLY = 100_000_000_000 * 10**18; // 100B tokens
    uint256 public constant FEE_PERCENT = 1; // 1% transfer fee

    event TeamWalletUpdated(address indexed oldWallet, address indexed newWallet);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with wallet allocations.
     * @param _teamWallet 25% allocation for development.
     * @param _presaleWallet 10% allocation for presale.
     * @param _airdropWallet 5% allocation for airdrop.
     * @param _stakingWallet 10% allocation for staking/rewards.
     * @param _marketingWallet 10% allocation for marketing.
     * @param _liquidityWallet 40% allocation for liquidity.
     */
    function initialize(
        address _teamWallet,
        address _presaleWallet,
        address _airdropWallet,
        address _stakingWallet,
        address _marketingWallet,
        address _liquidityWallet
    ) external initializer {
        require(_teamWallet != address(0), "Porkelon: Invalid team wallet");
        require(_presaleWallet != address(0), "Porkelon: Invalid presale wallet");
        require(_airdropWallet != address(0), "Porkelon: Invalid airdrop wallet");
        require(_stakingWallet != address(0), "Porkelon: Invalid staking wallet");
        require(_marketingWallet != address(0), "Porkelon: Invalid marketing wallet");
        require(_liquidityWallet != address(0), "Porkelon: Invalid liquidity wallet");

        __ERC20_init("Porkelon", "PORK");
        __ERC20Burnable_init();
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __AccessControl_init();

        teamWallet = _teamWallet;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        // Mint allocations
        _mint(_teamWallet, MAX_SUPPLY * 25 / 100); // 25%
        _mint(_presaleWallet, MAX_SUPPLY * 10 / 100); // 10%
        _mint(_airdropWallet, MAX_SUPPLY * 5 / 100); // 5%
        _mint(_stakingWallet, MAX_SUPPLY * 10 / 100); // 10%
        _mint(_marketingWallet, MAX_SUPPLY * 10 / 100); // 10%
        _mint(_liquidityWallet, MAX_SUPPLY * 40 / 100); // 40%
    }

    /**
     * @dev Updates team wallet. Only callable by owner.
     * @param newWallet New team wallet address.
     */
    function setTeamWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Porkelon: Invalid team wallet");
        address oldWallet = teamWallet;
        teamWallet = newWallet;
        emit TeamWalletUpdated(oldWallet, newWallet);
    }

    /**
     * @dev Overrides transfer to apply 1% fee (except mint/burn).
     */
    function _update(address from, address to, uint256 amount) internal override {
        require(!paused(), "Porkelon: Transfers paused");
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
        } else {
            uint256 fee = amount * FEE_PERCENT / 100;
            uint256 amountAfterFee = amount - fee;
            super._update(from, to, amountAfterFee);
            super._update(from, teamWallet, fee);
        }
    }

    /**
     * @dev Pauses token transfers. Only callable by PAUSER_ROLE.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses token transfers. Only callable by PAUSER_ROLE.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Authorizes upgrades. Only callable by UPGRADER_ROLE.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
