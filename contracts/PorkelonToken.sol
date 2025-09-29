// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
            super._update(from, to, amount);
        } else {
            uint256 fee = (amount * TRANSFER_FEE) / 10_000;
            uint256 amountAfterFee = amount - fee;
            if (fee > 0) {
                super._update(from, devWallet, fee);
            }
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

    // Pause contract
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    // Unpause contract
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Burn tokens
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


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// OpenZeppelin (upgradeable) imports
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title PorkelonToken
 * @dev Upgradeable ERC20 with burnable, pausable, access control, and a simple transfer fee.
 *      Dev/admin is set to the provided deployer address (devWallet constant set below).
 */
contract PorkelonToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // === Configurable wallets / addresses ===
    // Hard-coded dev wallet (per your request)
    address public constant DEV_WALLET = 0xBc2E051f3Dedcd0B9dDCA2078472f513a37df2C6;

    address public liquidityWallet;
    address public feeWallet;
    address public marketingWallet;

    // === Fee settings ===
    uint256 public constant FEE_PERCENT = 1; // 1%
    mapping(address => bool) public excludedFromFee;

    // === Token supply constants ===
    uint256 private constant DECIMALS = 18;
    uint256 private constant DECIMAL_FACTOR = 10**DECIMALS;
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * DECIMAL_FACTOR; // 100B * 1e18

    // Events
    event FeeCollected(address indexed from, address indexed to, uint256 fee);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the token.
     * @param _liquidityWallet Address to receive liquidity allocation (usually a locker contract or LP owner)
     * @param _marketingWallet Marketing wallet address
     *
     * After initialize:
     * - All tokens minted to this contract address.
     * - Owner / admin roles transferred to DEV_WALLET
     * - Fee wallet set to DEV_WALLET and several addresses excluded from fee.
     */
    function initialize(address _liquidityWallet, address _marketingWallet) public initializer {
        require(_liquidityWallet != address(0) && _marketingWallet != address(0), "Zero address");

        // Initialize inherited contracts
        __ERC20_init("Porkelon", "PORK");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        // Set wallets
        liquidityWallet = _liquidityWallet;
        marketingWallet = _marketingWallet;
        feeWallet = DEV_WALLET; // fees go to dev wallet by default

        // Mint entire supply to contract for controlled distribution
        _mint(address(this), TOTAL_SUPPLY);

        // Exemptions from fee (contract, dev, marketing, liquidity)
        excludedFromFee[address(this)] = true;
        excludedFromFee[DEV_WALLET] = true;
        excludedFromFee[_liquidityWallet] = true;
        excludedFromFee[_marketingWallet] = true;
        excludedFromFee[feeWallet] = true;

        // Grant roles to DEV_WALLET and set ownership to DEV_WALLET
        _grantRole(DEFAULT_ADMIN_ROLE, DEV_WALLET);
        _grantRole(PAUSER_ROLE, DEV_WALLET);
        _grantRole(UPGRADER_ROLE, DEV_WALLET);

        // Transfer contract ownership to DEV_WALLET (so dev controls owner-only actions)
        transferOwnership(DEV_WALLET);
    }

    // ------------------------
    // Transfer & fee logic
    // ------------------------
    /**
     * @dev Override _transfer to apply a simple 1% fee to transfers except when excluded.
     * Fee is sent to feeWallet.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual override {
        require(!paused(), "Token: paused");

        // If either party is excluded or either is zero address, do a normal transfer (also covers mint/burn)
        if (from == address(0) || to == address(0) || excludedFromFee[from] || excludedFromFee[to]) {
            super._transfer(from, to, amount);
            return;
        }

        // Calculate fee and net amount
        uint256 fee = (amount * FEE_PERCENT) / 100;
        uint256 net = amount - fee;

        // Transfer fee and net amount
        super._transfer(from, feeWallet, fee);
        super._transfer(from, to, net);

        emit FeeCollected(from, to, fee);
    }

    // ------------------------
    // Pausable (AccessControl)
    // ------------------------
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ------------------------
    // Admin helpers
    // ------------------------
    /// @notice Exclude/include an account from fees
    function setExcludedFromFee(address account, bool excluded) external onlyOwner {
        excludedFromFee[account] = excluded;
    }

    /// @notice Update the fee receiver wallet (onlyOwner)
    function updateFeeWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero address");
        // remove previous exemption if any
        excludedFromFee[feeWallet] = false;
        feeWallet = newWallet;
        excludedFromFee[newWallet] = true;
    }

    /// @notice Update marketing wallet
    function updateMarketingWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero address");
        marketingWallet = newWallet;
        excludedFromFee[newWallet] = true;
    }

    /**
     * @notice Distribute allocations from contract balance to designated addresses.
     * @dev Owner calls this after providing addresses for each pool/contract.
     */
    function distributeAllocations(
        address presaleContract,
        address airdropContract,
        address stakingContract,
        address liquidityLocker
    ) external onlyOwner nonReentrant {
        require(presaleContract != address(0) && airdropContract != address(0) && stakingContract != address(0) && liquidityLocker != address(0), "Zero address input");

        uint256 devAmt = (TOTAL_SUPPLY * 25) / 100; // 25%
        uint256 stakingAmt = (TOTAL_SUPPLY * 10) / 100; // 10%
        uint256 liquidityAmt = (TOTAL_SUPPLY * 40) / 100; // 40%
        uint256 marketingAmt = (TOTAL_SUPPLY * 10) / 100; // 10%
        uint256 airdropAmt = (TOTAL_SUPPLY * 5) / 100; // 5%
        uint256 presaleAmt = (TOTAL_SUPPLY * 10) / 100; // 10%

        // Transfers originate from contract's balance; contract is excluded from fees
        _transfer(address(this), DEV_WALLET, devAmt);
        _transfer(address(this), marketingWallet, marketingAmt);
        _transfer(address(this), presaleContract, presaleAmt);
        _transfer(address(this), airdropContract, airdropAmt);
        _transfer(address(this), stakingContract, stakingAmt);
        _transfer(address(this), liquidityLocker, liquidityAmt);
    }

    // ------------------------
    // UUPS upgrade authorization: only account with UPGRADER_ROLE
    // ------------------------
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // ------------------------
    // Fallback receive (for presale / ETH acceptance if needed)
    // ------------------------
    receive() external payable {}
}
