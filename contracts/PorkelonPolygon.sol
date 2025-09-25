// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract PorkelonPolygon is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // Wallets
    address public devWallet;
    address public liquidityWallet;
    address public feeWallet;

    // Pools
    uint256 public presalePool;
    uint256 public airdropPool;
    uint256 public stakingPool;
    uint256 public rewardsPool;
    uint256 public marketingPool;

    // Lock for liquidity only
    struct LockInfo {
        uint256 amount;
        uint256 releaseTimestamp;
        bool claimed;
    }
    LockInfo public liquidityLock;

    // Presale
    uint256 public presalePriceWeiPerToken;

    // Staking
    uint256 public totalStaked;
    mapping(address => uint256) public balancesStaked;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public periodFinish;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // Transaction fee
    uint256 public constant FEE_PERCENT = 1;

    // Constants
    uint256 private constant DECIMALS = 18;
    uint256 private constant DECIMAL_FACTOR = 10**DECIMALS;
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * DECIMAL_FACTOR;

    // Events
    event LockedReleased(address indexed beneficiary, uint256 amount);
    event PresaleBuy(address indexed buyer, uint256 tokenAmount, uint256 paidWei);
    event AirdropSent(address indexed recipient, uint256 amount);
    event Stake(address indexed user, uint256 amount);
    event WithdrawStake(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardNotified(uint256 amount, uint256 duration);
    event MarketingWithdrawn(address indexed to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _devWallet, address _liquidityWallet) public initializer {
        __ERC20_init("Porkelon", "PORK");
        __ERC20Burnable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        require(_devWallet != address(0) && _liquidityWallet != address(0), "zero address");

        devWallet = _devWallet;
        liquidityWallet = _liquidityWallet;
        feeWallet = _devWallet;

        // Allocation amounts
        uint256 devAmt = (TOTAL_SUPPLY * 25) / 100;
        uint256 stakingAmt = (TOTAL_SUPPLY * 10) / 100;
        uint256 liquidityAmt = (TOTAL_SUPPLY * 40) / 100;
        uint256 marketingAmt = (TOTAL_SUPPLY * 10) / 100;
        uint256 airdropAmt = (TOTAL_SUPPLY * 5) / 100;
        uint256 presaleAmt = (TOTAL_SUPPLY * 10) / 100;

        // Mint all tokens to contract initially
        _mint(address(this), TOTAL_SUPPLY);

        // Transfer dev allocation immediately to dev wallet (unlocked)
        _transfer(address(this), devWallet, devAmt);

        // Initialize pools
        presalePool = presaleAmt;
        airdropPool = airdropAmt;
        stakingPool = stakingAmt;
        rewardsPool = stakingAmt; // Rewards reserve
        marketingPool = marketingAmt;

        // Lock only liquidity
        liquidityLock = LockInfo(liquidityAmt, block.timestamp + 365 days, false);

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp;
    }

    // -----------------------------
    // Transfers with 1% fee
    // -----------------------------
    function _transfer(address from, address to, uint256 amount) internal override {
        if (from != address(0) && to != address(0) && feeWallet != address(0)) {
            uint256 fee = (amount * FEE_PERCENT) / 100;
            uint256 netAmount = amount - fee;
            super._transfer(from, feeWallet, fee);
            super._transfer(from, to, netAmount);
        } else {
            super._transfer(from, to, amount);
        }
    }

    // -----------------------------
    // Locks (liquidity only)
    // -----------------------------
    function claimLiquidityTokens() external nonReentrant {
        require(block.timestamp >= liquidityLock.releaseTimestamp, "liquidity locked");
        require(!liquidityLock.claimed, "already claimed");
        liquidityLock.claimed = true;
        _transfer(address(this), liquidityWallet, liquidityLock.amount);
        emit LockedReleased(liquidityWallet, liquidityLock.amount);
    }

    // -----------------------------
    // Presale
    // -----------------------------
    function setPresalePrice(uint256 weiPerToken) external onlyOwner {
        presalePriceWeiPerToken = weiPerToken;
    }

    function buyPresale(uint256 tokenAmount) external payable nonReentrant {
        require(tokenAmount <= presalePool, "not enough presale tokens");
        uint256 weiRequired = (presalePriceWeiPerToken * tokenAmount) / DECIMAL_FACTOR;
        require(msg.value >= weiRequired, "insufficient payment");

        presalePool -= tokenAmount;
        _transfer(address(this), msg.sender, tokenAmount);

        // Refund overpayment
        if (msg.value > weiRequired) {
            (bool sent, ) = msg.sender.call{value: msg.value - weiRequired}("");
            require(sent, "refund failed");
        }

        emit PresaleBuy(msg.sender, tokenAmount, weiRequired);
    }

    function withdrawPresaleProceeds(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "zero address");
        uint256 bal = address(this).balance;
        (bool ok, ) = to.call{value: bal}("");
        require(ok, "withdraw failed");
    }

    // -----------------------------
    // Airdrops
    // -----------------------------
    function airdropBatch(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner nonReentrant {
        require(recipients.length == amounts.length, "len mismatch");
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) total += amounts[i];
        require(total <= airdropPool, "not enough airdrop funds");

        airdropPool -= total;
        for (uint256 i = 0; i < recipients.length; i++) {
            address r = recipients[i];
            uint256 amt = amounts[i];
            require(r != address(0), "zero recipient");
            if (amt > 0) {
                _transfer(address(this), r, amt);
                emit AirdropSent(r, amt);
            }
        }
    }

    // -----------------------------
    // Marketing withdrawals
    // -----------------------------
    function withdrawMarketing(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "zero address");
        require(amount <= marketingPool, "not enough marketing funds");
        marketingPool -= amount;
        _transfer(address(this), to, amount);
        emit MarketingWithdrawn(to, amount);
    }

    // -----------------------------
    // Staking & rewards
    // -----------------------------
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * DECIMAL_FACTOR) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return (balancesStaked[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / DECIMAL_FACTOR + rewards[account];
    }

    function notifyRewardAmount(uint256 rewardAmount, uint256 durationSeconds) external onlyOwner updateReward(address(0)) {
        require(block.timestamp >= periodFinish, "previous period not finished");
        require(rewardAmount <= rewardsPool, "not enough rewards");
        require(durationSeconds > 0, "duration zero");

        rewardsPool -= rewardAmount;
        rewardRate = rewardAmount / durationSeconds;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + durationSeconds;

        emit RewardNotified(rewardAmount, durationSeconds);
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "zero stake");
        _transfer(msg.sender, address(this), amount);
        balancesStaked[msg.sender] += amount;
        totalStaked += amount;
        emit Stake(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "zero withdraw");
        require(balancesStaked[msg.sender] >= amount, "insufficient staked");
        balancesStaked[msg.sender] -= amount;
        totalStaked -= amount;
        _transfer(address(this), msg.sender, amount);
        emit WithdrawStake(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            _transfer(address(this), msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(balancesStaked[msg.sender]);
        getReward();
    }

    // -----------------------------
    // Admin: top up rewards pool
    // -----------------------------
    function topUpRewardsPool(uint256 amount) external onlyOwner {
        require(amount <= stakingPool, "not enough in staking pool");
        stakingPool -= amount;
        rewardsPool += amount;
    }

    // -----------------------------
    // UUPS
    // -----------------------------
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
