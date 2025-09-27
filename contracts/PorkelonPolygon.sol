// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract PorkelonPolygon is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    uint256 public constant MAX_SUPPLY = 100_000_000_000 * 10**18; // 100B tokens
    uint256 public constant TRANSFER_FEE = 100; // 1% (basis points, 100 = 1%)
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address public immutable devWallet;
    address public immutable stakingWallet;
    address public immutable liquidityWallet;
    address public immutable marketingWallet;
    address public immutable airdropWallet;
    address public immutable presaleWallet;

    mapping(address => uint256) public stakingBalance;
    mapping(address => uint256) public stakingStartTime;

    constructor(
        address _devWallet,
        address _stakingWallet,
        address _liquidityWallet,
        address _marketingWallet,
        address _airdropWallet,
        address _presaleWallet
    ) {
        devWallet = _devWallet;
        stakingWallet = _stakingWallet;
        liquidityWallet = _liquidityWallet;
        marketingWallet = _marketingWallet;
        airdropWallet = _airdropWallet;
        presaleWallet = _presaleWallet;
        _disableInitializers(); // Prevent initialization of implementation contract
    }

    function initialize() public initializer {
        __ERC20_init("Porkelon", "PORK");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        // Allocate tokens
        _mint(devWallet, (MAX_SUPPLY * 25) / 100);      // 25B to dev
        _mint(stakingWallet, (MAX_SUPPLY * 10) / 100);  // 10B to staking
        _mint(liquidityWallet, (MAX_SUPPLY * 40) / 100); // 40B to liquidity
        _mint(marketingWallet, (MAX_SUPPLY * 10) / 100); // 10B to marketing
        _mint(airdropWallet, (MAX_SUPPLY * 5) / 100);   // 5B to airdrops
        _mint(presaleWallet, (MAX_SUPPLY * 10) / 100);  // 10B to presale
    }

    // Override transfer to include 1% fee
    function _update(address from, address to, uint256 amount) internal override whenNotPaused {
        if (from == address(0) || to == address(0)) {
            // Minting or burning: no fee
            super._update(from, to, amount);
        } else {
            // Calculate 1% fee
            uint256 fee = (amount * TRANSFER_FEE) / 10_000;
            uint256 amountAfterFee = amount - fee;

            // Transfer fee to dev wallet
            if (fee > 0) {
                super._update(from, devWallet, fee);
            }
            // Transfer remaining amount to recipient
            super._update(from, to, amountAfterFee);
        }
    }

    // Stake tokens
    function stake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        if (stakingBalance[msg.sender] > 0) {
            _claimRewards(msg.sender);
        } else {
            stakingStartTime[msg.sender] = block.timestamp;
        }

        _transfer(msg.sender, address(this), amount);
        stakingBalance[msg.sender] += amount;
    }

    // Unstake tokens with rewards
    function unstake() external whenNotPaused {
        uint256 staked = stakingBalance[msg.sender];
        require(staked > 0, "No tokens staked");

        uint256 reward = _calculateRewards(msg.sender);
        stakingBalance[msg.sender] = 0;
        stakingStartTime[msg.sender] = 0;

        _transfer(address(this), msg.sender, staked);
        if (reward > 0) {
            _transfer(address(this), msg.sender, reward);
        }
    }

    // Pause contract (only pauser role)
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    // Unpause contract (only pauser role)
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Burn tokens (anyone can burn their own tokens)
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    // View pending rewards
    function getPendingRewards(address account) external view returns (uint256) {
        return _calculateRewards(account);
    }

    // Internal reward calculation (0.1% per day)
    function _calculateRewards(address account) internal view returns (uint256) {
        uint256 staked = stakingBalance[account];
        if (staked == 0) return 0;

        uint256 duration = block.timestamp - stakingStartTime[account];
        return (staked * duration * 1) / (1000 * 1 days);
    }

    // Internal function to claim rewards
    function _claimRewards(address account) internal {
        uint256 reward = _calculateRewards(account);
        if (reward > 0) {
            stakingStartTime[account] = block.timestamp;
            _transfer(address(this), account, reward);
        }
    }

    // UUPS upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
