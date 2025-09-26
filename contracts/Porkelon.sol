// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Porkelon is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public teamWallet;
    uint256 public constant MAX_SUPPLY = 100_000_000_000 * 10**18;
    uint256 public constant FEE_PERCENT = 1;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _teamWallet,
        address _presaleWallet,
        address _airdropWallet,
        address _stakingWallet,
        address _rewardsWallet,
        address _liquidityWallet
    ) public initializer {
        __ERC20_init("Porkelon", "PORK");
        __ERC20Burnable_init();
        __Ownable_init(msg.sender); // Pass initial owner
        __Pausable_init();
        __UUPSUpgradeable_init();
        __AccessControl_init();

        teamWallet = _teamWallet;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        // Mint and allocate
        uint256 teamAmount = MAX_SUPPLY * 20 / 100;
        uint256 presaleAmount = MAX_SUPPLY * 10 / 100;
        uint256 airdropAmount = MAX_SUPPLY * 10 / 100;
        uint256 stakingAmount = MAX_SUPPLY * 10 / 100;
        uint256 rewardsAmount = MAX_SUPPLY * 10 / 100;
        uint256 liquidityAmount = MAX_SUPPLY * 40 / 100;

        _mint(_teamWallet, teamAmount);
        _mint(_presaleWallet, presaleAmount);
        _mint(_airdropWallet, airdropAmount);
        _mint(_stakingWallet, stakingAmount);
        _mint(_rewardsWallet, rewardsAmount);
        _mint(_liquidityWallet, liquidityAmount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable, PausableUpgradeable) {
        require(!paused(), "Porkelon: token transfer paused");
        if (from == address(0) || to == address(0)) {
            // No fee on mint or burn
            super._update(from, to, value);
        } else {
            // Apply 1% fee to team wallet
            uint256 fee = value * FEE_PERCENT / 100;
            uint256 valueAfterFee = value - fee;
            super._update(from, to, valueAfterFee);
            super._update(from, teamWallet, fee);
        }
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
