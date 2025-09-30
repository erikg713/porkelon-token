// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Porkelon is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    address public presaleContract;
    address public stakingContract;
    mapping(address => bool) public isFeeExempt;

    event FeeExemptionUpdated(address indexed account, bool isExempt);
    event PresaleContractUpdated(address indexed newContract);
    event StakingContractUpdated(address indexed newContract);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address teamWallet,
        address presaleWallet,
        address airdropWallet,
        address stakingWallet,
        address marketingWallet,
        address liquidityWallet
    ) public initializer {
        __ERC20_init("Porkelon", "PORK");
        __ERC20Burnable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        // Mint initial allocations
        _mint(teamWallet, 25_000_000_000 * 10**18);
        _mint(presaleWallet, 10_000_000_000 * 10**18);
        _mint(airdropWallet, 5_000_000_000 * 10**18);
        _mint(stakingWallet, 10_000_000_000 * 10**18);
        _mint(marketingWallet, 10_000_000_000 * 10**18);
        _mint(liquidityWallet, 40_000_000_000 * 10**18);

        // Exempt core wallets from fees by default
        isFeeExempt[owner()] = true;
        isFeeExempt[teamWallet] = true;
        isFeeExempt[presaleWallet] = true;
        isFeeExempt[airdropWallet] = true;
        isFeeExempt[stakingWallet] = true;
        isFeeExempt[marketingWallet] = true;
        isFeeExempt[liquidityWallet] = true;
    }

    function _update(address from, address to, uint256 value) internal override {
        // Skip fees for exempt addresses or for minting
        if (isFeeExempt[from] || isFeeExempt[to] || from == address(0)) {
            super._update(from, to, value);
            return;
        }

        uint256 fee = (value * 1) / 100; // 1% fee
        uint256 amountToTransfer = value - fee;

        if (amountToTransfer > 0) {
            // Fee is burned by transferring to the zero address
            super._update(from, address(0), fee);
            super._update(from, to, amountToTransfer);
        } else {
            // If the value is too small, burn the whole amount
            super._update(from, address(0), value);
        }
    }
    
    function setFeeExempt(address account, bool isExempt) external onlyOwner {
        require(account != address(0), "Cannot set for the zero address");
        isFeeExempt[account] = isExempt;
        emit FeeExemptionUpdated(account, isExempt);
    }

    function setPresaleContract(address _presaleContract) external onlyOwner {
        if (presaleContract != address(0)) { isFeeExempt[presaleContract] = false; }
        presaleContract = _presaleContract;
        isFeeExempt[_presaleContract] = true;
        emit PresaleContractUpdated(_presaleContract);
    }

    function setStakingContract(address _stakingContract) external onlyOwner {
        if (stakingContract != address(0)) { isFeeExempt[stakingContract] = false; }
        stakingContract = _stakingContract;
        isFeeExempt[_stakingContract] = true;
        emit StakingContractUpdated(_stakingContract);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
