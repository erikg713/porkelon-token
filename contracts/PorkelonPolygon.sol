// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract PorkelonPolygon is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    address public deployerWallet;
    address public presaleWallet;
    address public airdropWallet;
    address public stakingRewardsWallet;
    address public liquidityWallet;

    event Initialized(address indexed owner, uint256 totalSupply);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _deployerWallet,
        address _presaleWallet,
        address _airdropWallet,
        address _stakingRewardsWallet,
        address _liquidityWallet
    ) public initializer {
        __ERC20_init("Porkelon", "PORK");
        __ERC20Burnable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        deployerWallet = _deployerWallet;
        presaleWallet = _presaleWallet;
        airdropWallet = _airdropWallet;
        stakingRewardsWallet = _stakingRewardsWallet;
        liquidityWallet = _liquidityWallet;

        uint256 total = 100_000_000_000 * (10 ** decimals());

        // Mint allocations
        _mint(deployerWallet, (total * 25) / 100);       // 25B for team -> deployer wallet
        _mint(stakingRewardsWallet, (total * 10) / 100); // 10B for staking/rewards
        _mint(liquidityWallet, (total * 40) / 100);      // 40B liquidity
        _mint(_deployerWallet, (total * 10) / 100);      // 10B marketing/ads
        _mint(airdropWallet, (total * 5) / 100);         // 5B airdrops
        _mint(presaleWallet, (total * 10) / 100);        // 10B presale

        transferOwnership(_deployerWallet);

        emit Initialized(_deployerWallet, total);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function allocationAmounts() external pure returns (
        uint256 deployerAmt,
        uint256 stakingAmt,
        uint256 liquidityAmt,
        uint256 marketingAmt,
        uint256 airdropAmt,
        uint256 presaleAmt,
        uint256 totalSupply
    ) {
        totalSupply = 100_000_000_000 * (10 ** 18);
        deployerAmt = (totalSupply * 25) / 100;
        stakingAmt = (totalSupply * 10) / 100;
        liquidityAmt = (totalSupply * 40) / 100;
        marketingAmt = (totalSupply * 10) / 100;
        airdropAmt = (totalSupply * 5) / 100;
        presaleAmt = (totalSupply * 10) / 100;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
  PorkelonPolygon.sol (Upgradeable Version)
  - ERC20 PORK (100,000,000,000 total)
  - Tokenomics allocations with locking:
      Dev (Team) 25% (locked 90 days)
      Presale 10%
      Airdrops 5%
      Staking allocation 5% (used to top up rewards or held as reserve)
      Rewards allocation 5%
      Marketing allocation 10%
      Liquidity lock 40% (locked 365 days)
  - Note: Allocations sum to 100%.
  - Presale buy with native chain currency (e.g., POL); price set by owner.
  - Airdrop multi-send by owner.
  - Staking (simple staking + time-bound reward distribution).
  - Owner controls for administration.
  - Made upgradeable with UUPS proxy pattern.
  - Added 1% transaction fee to team wallet (on transfers, excludes mints/burns).
*/

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract PorkelonPolygon is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    uint8 private constant _DECIMALS = 18;
    uint256 public constant DECIMAL_FACTOR = 10 ** uint256(_DECIMALS);

    uint256 public constant TOTAL_SUPPLY = 100_000_000_000 * DECIMAL_FACTOR; // 100B

    // Tokenomics percentages (integer percentages; sum to 100%)
    uint256 public constant DEV_PCT = 25; // Dev (team)
    uint256 public constant PRESALE_PCT = 10;
    uint256 public constant AIRDROP_PCT = 5;
    uint256 public constant STAKING_PCT = 5;
    uint256 public constant REWARDS_PCT = 5;
    uint256 public constant MARKETING_PCT = 10;
    uint256 public constant LIQUIDITY_PCT = 40;

    // Derived allocations
    uint256 public devAllocation;
    uint256 public presaleAllocation;
    uint256 public airdropAllocation;
    uint256 public stakingAllocation;
    uint256 public rewardsAllocation;
    uint256 public marketingAllocation;
    uint256 public liquidityAllocation;

    // Lock durations (seconds)
    uint256 public constant LOCK_90_DAYS = 90 days;
    uint256 public constant LOCK_365_DAYS = 365 days;

    // Lock structs
    struct LockInfo {
        uint256 amount;
        uint256 releaseTimestamp;
        bool claimed;
    }

    // Dev (team) lock and liquidity lock addresses
    address public devWallet; // Previously teamWallet
    address public liquidityWallet;

    // Pools (funds held in contract until distributed / claimed)
    uint256 public presalePool; // available for presale buyers
    uint256 public airdropPool;
    uint256 public stakingPool; // reserve for staking/rewards top-up (owner can move to rewardsPool)
    uint256 public rewardsPool; // used to pay staking rewards
    uint256 public marketingPool; // for marketing; owner can withdraw
    LockInfo public devLock; // Previously teamLock
    LockInfo public liquidityLock;

    // Presale price (wei per full token, i.e., for 10^18 units)
    uint256 public presalePriceWeiPerToken; // default 0 (owner sets)

    // --- Staking variables (simple reward distribution) ---
    uint256 public totalStaked;
    mapping(address => uint256) public balancesStaked;

    // reward accounting
    uint256 public rewardRate; // reward tokens distributed per second
    uint256 public lastUpdateTime;
    uint256 public periodFinish;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards; // earned but not claimed

    // Transaction fee (1% to devWallet)
    uint256 public constant FEE_PERCENT = 1;
    address public feeWallet; // Wallet for collecting 1% transaction fees (set to devWallet)

    // Events
    event PresaleBuy(address indexed buyer, uint256 tokenAmount, uint256 paidWei);
    event AirdropSent(address indexed recipient, uint256 amount);
    event Stake(address indexed user, uint256 amount);
    event WithdrawStake(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardNotified(uint256 amount, uint256 duration);
    event LockedReleased(address indexed beneficiary, uint256 amount);
    event PresalePriceSet(uint256 weiPerToken);
    event MarketingWithdrawn(address indexed to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _devWallet, address _liquidityWallet) public initializer {
        __ERC20_init("Porkelon", "PORK");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        require(_devWallet != address(0) && _liquidityWallet != address(0), "zero address");

        devWallet = _devWallet;
        liquidityWallet = _liquidityWallet;
        feeWallet = _devWallet; // Fees go to devWallet

        // calculate allocations
        devAllocation = (TOTAL_SUPPLY * DEV_PCT) / 100;
        presaleAllocation = (TOTAL_SUPPLY * PRESALE_PCT) / 100;
        airdropAllocation = (TOTAL_SUPPLY * AIRDROP_PCT) / 100;
        stakingAllocation = (TOTAL_SUPPLY * STAKING_PCT) / 100;
        rewardsAllocation = (TOTAL_SUPPLY * REWARDS_PCT) / 100;
        marketingAllocation = (TOTAL_SUPPLY * MARKETING_PCT) / 100;
        liquidityAllocation = (TOTAL_SUPPLY * LIQUIDITY_PCT) / 100;

        // Mint TOTAL_SUPPLY to this contract (keeps control to distribute)
        _mint(address(this), TOTAL_SUPPLY);

        // Initialize pools by moving allocation amounts to bookkeeping pools (tokens remain in contract)
        presalePool = presaleAllocation;
        airdropPool = airdropAllocation;
        stakingPool = stakingAllocation;
        rewardsPool = rewardsAllocation;
        marketingPool = marketingAllocation;

        // Dev and liquidity are locked; fill LockInfo (tokens stay in contract until claim)
        devLock = LockInfo({ amount: devAllocation, releaseTimestamp: block.timestamp + LOCK_90_DAYS, claimed: false });
        liquidityLock = LockInfo({ amount: liquidityAllocation, releaseTimestamp: block.timestamp + LOCK_365_DAYS, claimed: false });

        // Set default presale price to 0 (owner should set)
        presalePriceWeiPerToken = 0;

        // Initial reward accounting
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp;
    }

    // Required for UUPS
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // -----------------------
    // Presale
    // -----------------------

    // Owner sets presale price in wei per full token (for 10^18 units)
    function setPresalePrice(uint256 weiPerToken) external onlyOwner {
        presalePriceWeiPerToken = weiPerToken;
        emit PresalePriceSet(weiPerToken);
    }

    // Buy presale tokens by sending native currency (e.g., POL) — buyer specifies tokenAmount (with decimals)
    function buyPresale(uint256 tokenAmount) external payable nonReentrant {
        require(presalePriceWeiPerToken > 0, "presale price not set");
        require(tokenAmount > 0, "zero tokens");
        uint256 weiRequired = (presalePriceWeiPerToken * tokenAmount) / DECIMAL_FACTOR;
        require(msg.value >= weiRequired, "insufficient payment");
        require(tokenAmount <= presalePool, "not enough presale tokens");

        presalePool -= tokenAmount;

        // transfer tokens from contract to buyer
        _transfer(address(this), msg.sender, tokenAmount);

        // refund overpayment if any
        if (msg.value > weiRequired) {
            (bool sent, ) = msg.sender.call{ value: msg.value - weiRequired }("");
            require(sent, "refund failed");
        }

        emit PresaleBuy(msg.sender, tokenAmount, weiRequired);
    }

    // Owner can withdraw accumulated native funds from presale
    function withdrawPresaleProceeds(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "zero address");
        uint256 bal = address(this).balance;
        require(bal > 0, "no proceeds");
        (bool ok, ) = to.call{ value: bal }("");
        require(ok, "withdraw failed");
    }

    // -----------------------
    // Airdrops
    // -----------------------

    // Batch airdrop: arrays of recipients & amounts (amounts with decimals)
    function airdropBatch(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner nonReentrant {
        require(recipients.length == amounts.length, "len mismatch");
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
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

    // -----------------------
    // Marketing
    // -----------------------

    // Owner can withdraw from marketingPool to a specified address (e.g., marketing wallet)
    function withdrawMarketing(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "zero address");
        require(amount > 0, "zero amount");
        require(amount <= marketingPool, "not enough in marketing pool");

        marketingPool -= amount;
        _transfer(address(this), to, amount);
        emit MarketingWithdrawn(to, amount);
    }

    // -----------------------
    // Locks (dev & liquidity)
    // -----------------------

    // Claim dev tokens after lock time (caller can be anyone, but transfers to devWallet)
    function claimDevTokens() external nonReentrant {
        require(block.timestamp >= devLock.releaseTimestamp, "dev locked");
        require(!devLock.claimed, "already claimed");
        devLock.claimed = true;
        uint256 amt = devLock.amount;
        require(amt > 0, "no dev tokens");
        _transfer(address(this), devWallet, amt);
        emit LockedReleased(devWallet, amt);
    }

    // Claim liquidity tokens after lock time (caller can be anyone, but transfers to liquidityWallet)
    function claimLiquidityTokens() external nonReentrant {
        require(block.timestamp >= liquidityLock.releaseTimestamp, "liquidity locked");
        require(!liquidityLock.claimed, "already claimed");
        liquidityLock.claimed = true;
        uint256 amt = liquidityLock.amount;
        require(amt > 0, "no liquidity tokens");
        _transfer(address(this), liquidityWallet, amt);
        emit LockedReleased(liquidityWallet, amt);
    }

    // -----------------------
    // Staking & Rewards (simple)
    // -----------------------

    // Owner calls to start a reward distribution: specify amount from rewardsPool and duration
    // Require previous period finished to simplify
    function notifyRewardAmount(uint256 rewardAmount, uint256 durationSeconds) external onlyOwner updateReward(address(0)) {
        require(block.timestamp >= periodFinish, "previous period not finished");
        require(durationSeconds > 0, "duration zero");
        require(rewardAmount > 0, "reward zero");
        require(rewardAmount <= rewardsPool, "not enough rewards in pool");

        rewardsPool -= rewardAmount;
        rewardRate = rewardAmount / durationSeconds;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + durationSeconds;

        emit RewardNotified(rewardAmount, durationSeconds);
    }

    // Stake tokens (from caller). Tokens transferred to contract.
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "zero stake");
        _transfer(msg.sender, address(this), amount);
        balancesStaked[msg.sender] += amount;
        totalStaked += amount;
        emit Stake(msg.sender, amount);
    }

    // Withdraw stake (returns staked tokens)
    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "zero withdraw");
        require(balancesStaked[msg.sender] >= amount, "insufficient staked");
        balancesStaked[msg.sender] -= amount;
        totalStaked -= amount;
        _transfer(address(this), msg.sender, amount);
        emit WithdrawStake(msg.sender, amount);
    }

    // Claim earned rewards
    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            _transfer(address(this), msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    // Exit: withdraw stake and claim rewards
    function exit() external {
        withdraw(balancesStaked[msg.sender]);
        getReward();
    }

    // -----------------------
    // Reward accounting helpers
    // -----------------------

    // Last time reward applicable (min of now and periodFinish)
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    // Reward per token
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        uint256 dt = lastTimeRewardApplicable() - lastUpdateTime;
        return rewardPerTokenStored + (dt * rewardRate * DECIMAL_FACTOR) / totalStaked;
    }

    // Earned rewards for account
    function earned(address account) public view returns (uint256) {
        return (balancesStaked[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / DECIMAL_FACTOR + rewards[account];
    }

    // Modifier to update reward accounting
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // -----------------------
    // Transaction Fee (1% to feeWallet)
    // -----------------------

    // Override transfer to apply 1% fee on transfers (not on mints/burns)
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0) && feeWallet != address(0)) { // Apply fee only on transfers
            uint256 fee = (value * FEE_PERCENT) / 100; // 1% fee
            uint256 amountAfterFee = value - fee;
            super._update(from, feeWallet, fee); // Send fee to feeWallet
            super._update(from, to, amountAfterFee); // Send remaining to recipient
        } else {
            super._update(from, to, value);
        }
    }

    // Optional: Function to update feeWallet (only owner, for flexibility)
    function setFeeWallet(address newFeeWallet) public onlyOwner {
        require(newFeeWallet != address(0), "Invalid address");
        feeWallet = newFeeWallet;
    }

    // -----------------------
    // Admin utilities & emergency
    // -----------------------

    // Owner can move from stakingPool to rewardsPool
    function topUpRewardsPool(uint256 amount) external onlyOwner {
        require(amount <= stakingPool, "not enough in staking pool");
        stakingPool -= amount;
        rewardsPool += amount;
    }

    // If owner needs to withdraw unallocated tokens from presale/airdrop/staking/rewards/marketing pools back to owner
    function recoverUnallocated(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "zero");
        require(amount <= (presalePool + airdropPool + stakingPool + rewardsPool + marketingPool), "not enough unallocated");
        // prefer to remove from presale, then airdrop, then staking, then rewards, then marketing
        uint256 remaining = amount;
        if (presalePool >= remaining) {
            presalePool -= remaining;
            remaining = 0;
        } else {
            remaining -= presalePool;
            presalePool = 0;
        }

        if (remaining > 0) {
            if (airdropPool >= remaining) {
                airdropPool -= remaining;
                remaining = 0;
            } else {
                remaining -= airdropPool;
                airdropPool = 0;
            }
        }

        if (remaining > 0) {
            if (stakingPool >= remaining) {
                stakingPool -= remaining;
                remaining = 0;
            } else {
                remaining -= stakingPool;
                stakingPool = 0;
            }
        }

        if (remaining > 0) {
            if (rewardsPool >= remaining) {
                rewardsPool -= remaining;
                remaining = 0;
            } else {
                remaining -= rewardsPool;
                rewardsPool = 0;
            }
        }

        if (remaining > 0) {
            marketingPool -= remaining;
            remaining = 0;
        }

        // transfer tokens to owner
        _transfer(address(this), owner(), amount);
    }

    // Emergency function: owner can rescue native currency mistakenly sent to contract (except presale proceeds, which use withdrawPresaleProceeds)
    function rescueNative(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "zero");
        uint256 bal = address(this).balance;
        require(bal > 0, "no balance");
        (bool ok, ) = to.call{ value: bal }("");
        require(ok, "rescue failed");
    }

    // Fallback payable to accept presale payments or accidental sends
    receive() external payable {}

    // -----------------------
    // Views for pool balances & status
    // -----------------------
    function contractTokenBalance() external view returns (uint256) {
        return balanceOf(address(this));
    }

    function devLockedInfo() external view returns (uint256 amount, uint256 release, bool claimed) {
        return (devLock.amount, devLock.releaseTimestamp, devLock.claimed);
    }

    function liquidityLockedInfo() external view returns (uint256 amount, uint256 release, bool claimed) {
        return (liquidityLock.amount, liquidityLock.releaseTimestamp, liquidityLock.claimed);
    }

    // -----------------------
    // Safety: decimals override
    // -----------------------
    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }
}
