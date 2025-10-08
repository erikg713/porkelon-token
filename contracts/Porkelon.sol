// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title Porkelon (PORK) - Upgradeable ERC20 with configurable burn fee and exemptions
/// @notice Gas- and security-conscious upgrade of the original contract:
/// - fixes incorrect override usage (uses _transfer instead of non-existent _update)
/// - adds configurable fee (basis points) with caps and events
/// - improves initializer usage for upgradeable contracts and adds input validation
contract Porkelon is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    // Fee is stored in basis points (bps). 100 bps = 1%.
    // Allows fine-grained control while minimizing storage writes when unchanged.
    uint16 public feeBps; // e.g., 100 = 1%
    uint16 public constant MAX_FEE_BPS = 1000; // 10% maximum fee, safety limit

    address public presaleContract;
    address public stakingContract;

    mapping(address => bool) public isFeeExempt;

    event FeeExemptionUpdated(address indexed account, bool isExempt);
    event PresaleContractUpdated(address indexed newContract);
    event StakingContractUpdated(address indexed newContract);
    event FeeBpsUpdated(uint16 previousBps, uint16 newBps);
    event TokensRescued(address indexed token, address indexed to, uint256 amount);
    event EtherRescued(address indexed to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract and mints initial allocations.
    /// @dev All input wallets must be non-zero; ownership is set via __Ownable_init().
    function initialize(
        address teamWallet,
        address presaleWallet,
        address airdropWallet,
        address stakingWallet,
        address marketingWallet,
        address liquidityWallet
    ) public initializer {
        require(teamWallet != address(0), "team wallet is zero");
        require(presaleWallet != address(0), "presale wallet is zero");
        require(airdropWallet != address(0), "airdrop wallet is zero");
        require(stakingWallet != address(0), "staking wallet is zero");
        require(marketingWallet != address(0), "marketing wallet is zero");
        require(liquidityWallet != address(0), "liquidity wallet is zero");

        __ERC20_init("Porkelon", "PORK");
        __ERC20Burnable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        // default fee: 1% (100 bps)
        feeBps = 100;

        uint256 unit = 10 ** uint256(decimals());

        // Mint initial allocations
        _mint(teamWallet, 25_000_000_000 * unit);
        _mint(presaleWallet, 10_000_000_000 * unit);
        _mint(airdropWallet, 5_000_000_000 * unit);
        _mint(stakingWallet, 10_000_000_000 * unit);
        _mint(marketingWallet, 25_000_000_000 * unit);
        _mint(liquidityWallet, 25_000_000_000 * unit);

        // Exempt core wallets and owner from fees by default
        isFeeExempt[owner()] = true;
        isFeeExempt[teamWallet] = true;
        isFeeExempt[presaleWallet] = true;
        isFeeExempt[airdropWallet] = true;
        isFeeExempt[stakingWallet] = true;
        isFeeExempt[marketingWallet] = true;
        isFeeExempt[liquidityWallet] = true;

        presaleContract = presaleWallet;
        stakingContract = stakingWallet;
    }

    /// @notice Internal transfer hook overridden to apply a configurable burn fee unless exempt.
    /// @dev Uses basis points calculation, safely handles extremely small transfers by burning entire amount if fee >= amount.
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        // Skip fee logic for mints/burns or exempted addresses
        if (sender == address(0) || recipient == address(0) || isFeeExempt[sender] || isFeeExempt[recipient] || feeBps == 0) {
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 fee = (amount * feeBps) / 10_000;
        if (fee == 0) {
            // fee too small to collect; do a normal transfer
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 amountToTransfer = amount - fee;

        // If fee is >= amount (shouldn't happen with sensible feeBps), burn entire amount to avoid underflow.
        if (amountToTransfer == 0) {
            // Burn whole amount
            _burn(sender, amount);
            return;
        }

        // Burn fee and transfer remainder
        // Burn reduces total supply and sender balance; then transfer the remainder.
        _burn(sender, fee);
        super._transfer(sender, recipient, amountToTransfer);
    }

    /// @notice Set an address as fee-exempt or not.
    function setFeeExempt(address account, bool isExempt) external onlyOwner {
        require(account != address(0), "Cannot set zero address");
        isFeeExempt[account] = isExempt;
        emit FeeExemptionUpdated(account, isExempt);
    }

    /// @notice Update presale contract and ensure fee exemption is managed.
    function setPresaleContract(address _presaleContract) external onlyOwner {
        if (presaleContract != address(0) && presaleContract != _presaleContract) {
            isFeeExempt[presaleContract] = false;
            emit FeeExemptionUpdated(presaleContract, false);
        }
        presaleContract = _presaleContract;
        if (_presaleContract != address(0)) {
            isFeeExempt[_presaleContract] = true;
            emit FeeExemptionUpdated(_presaleContract, true);
        }
        emit PresaleContractUpdated(_presaleContract);
    }

    /// @notice Update staking contract and ensure fee exemption is managed.
    function setStakingContract(address _stakingContract) external onlyOwner {
        if (stakingContract != address(0) && stakingContract != _stakingContract) {
            isFeeExempt[stakingContract] = false;
            emit FeeExemptionUpdated(stakingContract, false);
        }
        stakingContract = _stakingContract;
        if (_stakingContract != address(0)) {
            isFeeExempt[_stakingContract] = true;
            emit FeeExemptionUpdated(_stakingContract, true);
        }
        emit StakingContractUpdated(_stakingContract);
    }

    /// @notice Update the fee (in basis points). Max allowed is MAX_FEE_BPS.
    function setFeeBps(uint16 _feeBps) external onlyOwner {
        require(_feeBps <= MAX_FEE_BPS, "Fee exceeds maximum");
        emit FeeBpsUpdated(feeBps, _feeBps);
        feeBps = _feeBps;
    }

    /// @notice Rescue ERC20 tokens accidentally sent to this contract.
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to is zero");
        require(token != address(this), "Cannot rescue native token");
        // Use low-level transfer for arbitrary tokens; rely on token implementation
        bool sent = IERC20Upgradeable(token).transfer(to, amount);
        require(sent, "Token transfer failed");
        emit TokensRescued(token, to, amount);
    }

    /// @notice Rescue stuck ETH sent to this contract.
    function rescueEther(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "to is zero");
        (bool success, ) = to.call{value: amount}("");
        require(success, "Ether transfer failed");
        emit EtherRescued(to, amount);
    }

    /// @dev UUPS Authorize - limited to owner
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // Reserved storage gap for future upgrades (compiles with OZ upgradeable pattern)
    uint256[45] private __gap;
}
