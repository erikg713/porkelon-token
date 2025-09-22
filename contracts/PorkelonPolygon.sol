// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
  PorkelonPolygon.sol
  - ERC20 PORK (100,000,000,000 total)
  - Tokenomics allocations with locking:
      Team 20% (locked 365 days)
      Presale 10%
      Airdrops 10%
      Staking allocation 10%
      Rewards allocation 10%
      Liquidity lock 40% (locked 365 days)
  - Presale buy (payable — native chain e.g., MATIC)
  - Airdrop multi-send
  - Staking (simple staking + reward distribution pattern)
  - Owner controls for administration
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PorkelonPolygon is ERC20, Ownable, ReentrancyGuard {
    uint8 private constant _DECIMALS = 18;
    uint256 public constant DECIMAL_FACTOR = 10 ** uint256(_DECIMALS);

    uint256 public constant TOTAL_SUPPLY = 100_000_000_000 * DECIMAL_FACTOR; // 100B

    // Tokenomics percentages (integer percentages)
    uint256 public constant TEAM_PCT = 20;
    uint256 public constant PRESALE_PCT = 10;
    uint256 public constant AIRDROP_PCT = 10;
    uint256 public constant STAKING_PCT = 10;
    uint256 public constant REWARDS_PCT = 10;
    uint256 public constant LIQUIDITY_PCT = 40;

    // Derived allocations
    uint256 public immutable teamAllocation;
    uint256 public immutable presaleAllocation;
    uint256 public immutable airdropAllocation;
    uint256 public immutable stakingAllocation;
    uint256 public immutable rewardsAllocation;
    uint256 public immutable liquidityAllocation;

    // Lock durations (seconds)
    uint256 public constant LOCK_365_DAYS = 365 days;

    // Lock structs
    struct LockInfo {
        uint256 amount;
        uint256 releaseTimestamp;
        bool claimed;
    }

    // Team lock and liquidity lock addresses
    address public immutable teamWallet;
    address public immutable liquidityWallet;

    // Pools (funds held in contract until distributed / claimed)
    uint256 public presalePool; // available for presale buyers
    uint256 public airdropPool;
    uint256 public stakingPool; // used for users withdraws or staking logic
    uint256 public rewardsPool; // used to pay staking rewards
    LockInfo public teamLock;
    LockInfo public liquidityLock;

    // Presale price (wei per token unit with decimals)
    // For usability, we will set price as wei per token *with decimals*, i.e., buyer pays price * tokenAmount
    uint256 public presalePriceWeiPerToken; // default 0 (owner sets)

    // --- Staking variables (simple reward distribution) ---
    uint256 public totalStaked;
    mapping(address => uint256) public balancesStaked;

    // reward accounting
    uint256 public rewardRate; // reward tokens distributed per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards; // earned but not claimed

    // Events
    event PresaleBuy(address indexed buyer, uint256 tokenAmount, uint256 paidWei);
    event AirdropSent(address indexed recipient, uint256 amount);
    event Stake(address indexed user, uint256 amount);
    event WithdrawStake(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardNotified(uint256 amount, uint256 duration);
    event LockedReleased(address indexed beneficiary, uint256 amount);
    event PresalePriceSet(uint256 weiPerToken);

    constructor(address _teamWallet, address _liquidityWallet) ERC20("Porkelon", "PORK") {
        require(_teamWallet != address(0) && _liquidityWallet != address(0), "zero address");

        teamWallet = _teamWallet;
        liquidityWallet = _liquidityWallet;

        // calculate allocations
        teamAllocation = (TOTAL_SUPPLY * TEAM_PCT) / 100;
        presaleAllocation = (TOTAL_SUPPLY * PRESALE_PCT) / 100;
        airdropAllocation = (TOTAL_SUPPLY * AIRDROP_PCT) / 100;
        stakingAllocation = (TOTAL_SUPPLY * STAKING_PCT) / 100;
        rewardsAllocation = (TOTAL_SUPPLY * REWARDS_PCT) / 100;
        liquidityAllocation = (TOTAL_SUPPLY * LIQUIDITY_PCT) / 100;

        // Mint TOTAL_SUPPLY to this contract (keeps control to distribute)
        _mint(address(this), TOTAL_SUPPLY);

        // Initialize pools by moving allocation amounts to bookkeeping pools (tokens remain in contract)
        presalePool = presaleAllocation;
        airdropPool = airdropAllocation;
        stakingPool = stakingAllocation;
        rewardsPool = rewardsAllocation;

        // Team and liquidity are locked; fill LockInfo (tokens stay in contract until claim)
        teamLock = LockInfo({ amount: teamAllocation, releaseTimestamp: block.timestamp + LOCK_365_DAYS, claimed: false });
        liquidityLock = LockInfo({ amount: liquidityAllocation, releaseTimestamp: block.timestamp + LOCK_365_DAYS, claimed: false });

        // Set default presale price to 0 (owner should set)
        presalePriceWeiPerToken = 0;
    }

    // -----------------------
    // Presale
    // -----------------------

    // Owner sets presale price in wei per token (considering decimals, price applies to token units already including 18 decimals)
    function setPresalePrice(uint256 weiPerToken) external onlyOwner {
        presalePriceWeiPerToken = weiPerToken;
        emit PresalePriceSet(weiPerToken);
    }

    // Buy presale tokens by sending native currency (e.g., MATIC) — buyer receives `tokenAmount` tokens
    function buyPresale(uint256 tokenAmount) external payable nonReentrant {
        require(presalePriceWeiPerToken > 0, "presale price not set");
        require(tokenAmount > 0, "zero tokens");
        uint256 weiRequired = (presalePriceWeiPerToken * tokenAmount) / DECIMAL_FACTOR; // price scaling
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

    // Batch airdrop: arrays of recipients & amounts (amounts must be token amounts with decimals)
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
    // Locks (team & liquidity)
    // -----------------------

    // Owner can release team tokens after lock time
    function claimTeamTokens() external nonReentrant {
        require(block.timestamp >= teamLock.releaseTimestamp, "team locked");
        require(!teamLock.claimed, "already claimed");
        teamLock.claimed = true;
        uint256 amt = teamLock.amount;
        require(amt > 0, "no team tokens");
        _transfer(address(this), teamWallet, amt);
        emit LockedReleased(teamWallet, amt);
    }

    // Owner or designated liquidity manager can claim liquidity tokens after lock time
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

    // Owner calls to start a reward distribution: owner must ensure contract has at least `amount` in rewardsPool
    // Duration is seconds over which rewards are distributed.
    function notifyRewardAmount(uint256 rewardAmount, uint256 durationSeconds) external onlyOwner updateReward(address(0)) {
        require(durationSeconds > 0, "duration zero");
        require(rewardAmount > 0, "reward zero");
        require(rewardAmount <= rewardsPool, "not enough rewards in pool");

        // transfer reward accounting from rewardsPool into active reward distribution
        rewardsPool -= rewardAmount;

        // set rewardRate to rewardAmount / duration
        rewardRate = rewardAmount / durationSeconds;
        lastUpdateTime = block.timestamp;

        emit RewardNotified(rewardAmount, durationSeconds);
    }

    // Stake tokens (from caller). Tokens used for staking come from user's wallet, transferred to contract.
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "zero stake");
        // transfer tokens to contract (reduces user balance, increases contract balance)
        _transfer(msg.sender, address(this), amount);

        balancesStaked[msg.sender] += amount;
        totalStaked += amount;

        // Optionally, stakingPool can be used as the source for payouts/withdraws if required — we keep staked tokens in contract
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
            // send reward tokens from contract to user
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

    // rewardPerToken and earned follow common staking patterns
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        uint256 dt = block.timestamp - lastUpdateTime;
        return rewardPerTokenStored + ((dt * rewardRate * DECIMAL_FACTOR) / totalStaked);
    }

    function earnedView(address account) public view returns (uint256) {
        return (balancesStaked[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / DECIMAL_FACTOR + rewards[account];
    }

    // modifier to update reward accounting
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earnedView(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // -----------------------
    // Admin utilities & emergency
    // -----------------------

    // Owner can top-up rewardPool or stakingPool (send tokens from owner to this contract)
    // But since contract holds tokens from initial mint, owner can reassign amounts between bookkeeping pools:
    function topUpRewardsPool(uint256 amount) external onlyOwner {
        require(amount <= balanceOf(address(this)), "not enough contract tokens");
        rewardsPool += amount;
    }

    function topUpStakingPool(uint256 amount) external onlyOwner {
        require(amount <= balanceOf(address(this)), "not enough contract tokens");
        stakingPool += amount;
    }

    // If owner needs to withdraw unallocated tokens from presale/airdrop/staking/rewards pools back to owner
    function recoverUnallocated(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "zero");
        require(amount <= (presalePool + airdropPool + stakingPool + rewardsPool), "not enough unallocated");
        // prefer to remove from presale, then airdrop, then staking, then rewards
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
                revert("insufficient unallocated after pools");
            }
        }

        // transfer tokens to owner
        _transfer(address(this), owner(), amount);
    }

    // Emergency function: owner can rescue native currency mistakenly sent to contract
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

    function teamLockedInfo() external view returns (uint256 amount, uint256 release, bool claimed) {
        return (teamLock.amount, teamLock.releaseTimestamp, teamLock.claimed);
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
