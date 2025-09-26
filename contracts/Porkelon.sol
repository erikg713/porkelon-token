// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title Porkelon
 * @dev Upgradeable ERC20 token on Polygon with burnable, pausable, access control, and 1% transfer fee to team wallet.
 */
contract Porkelon is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public teamWallet;
    uint256 public constant MAX_SUPPLY = 100_000_000_000 * 10**18; // 100B tokens
    uint256 public constant FEE_PERCENT = 1; // 1% transfer fee

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with wallet allocations and roles.
     * @param _teamWallet Team wallet for fees and 20% allocation.
     * @param _presaleWallet 10% allocation for presale.
     * @param _airdropWallet 10% allocation for airdrop.
     * @param _stakingWallet 10% allocation for staking.
     * @param _rewardsWallet 10% allocation for rewards.
     * @param _liquidityWallet 40% allocation for liquidity.
     */
    function initialize(
        address _teamWallet,
        address _presaleWallet,
        address _airdropWallet,
        address _stakingWallet,
        address _rewardsWallet,
        address _liquidityWallet
    ) public initializer {
        require(_teamWallet != address(0), "Invalid team wallet");
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

        // Mint and allocate (no further minting possible)
        uint256 teamAmount = MAX_SUPPLY * 20 / 100; // 20%
        uint256 presaleAmount = MAX_SUPPLY * 10 / 100; // 10%
        uint256 airdropAmount = MAX_SUPPLY * 10 / 100; // 10%
        uint256 stakingAmount = MAX_SUPPLY * 10 / 100; // 10%
        uint256 rewardsAmount = MAX_SUPPLY * 10 / 100; // 10%
        uint256 liquidityAmount = MAX_SUPPLY * 40 / 100; // 40%

        _mint(_teamWallet, teamAmount);
        _mint(_presaleWallet, presaleAmount);
        _mint(_airdropWallet, airdropAmount);
        _mint(_stakingWallet, stakingAmount);
        _mint(_rewardsWallet, rewardsAmount);
        _mint(_liquidityWallet, liquidityAmount);
    }

    /**
     * @dev Overrides transfer to apply 1% fee to team wallet (except mint/burn).
     */
    function _update(address from, address to, uint256 amount) internal override {
        require(!paused(), "Porkelon: Token transfers paused");
        if (from == address(0) || to == address(0)) {
            // No fee on mint or burn
            super._update(from, to, amount);
        } else {
            // Apply 1% fee to team wallet
            uint256 fee = amount * FEE_PERCENT / 100;
            uint256 amountAfterFee = amount - fee;
            super._update(from, to, amountAfterFee);
            super._update(from, teamWallet, fee);
        }
    }

    /**
     * @dev Pauses token transfers. Only callable by PAUSER_ROLE.
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses token transfers. Only callable by PAUSER_ROLE.
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Authorizes contract upgrades. Only callable by UPGRADER_ROLE.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
