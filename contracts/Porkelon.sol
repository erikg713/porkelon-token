// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Uniswap V3 (QuickSwap on Polygon) interfaces
interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params) external returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    function positions(uint256 tokenId) external view returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );
}

interface IWMATIC {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

function collectFees(uint256 tokenId, uint128 amount0Max, uint128 amount1Max) external onlyRole(DEFAULT_ADMIN_ROLE) {
    INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER).collect(
        INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: multisig,
            amount0Max: amount0Max,
            amount1Max: amount1Max
        })
    );
}

contract Porkelon is ERC20, ERC20Burnable, ERC20Permit, AccessControl, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    mapping(bytes32 => bool) public usedNonces; // Replay protection for bridge
    address public immutable multisig; // Gnosis Safe address for admin control
    string public metadataURI; // Optional metadata (e.g., logo, description)

    // Staking Implementation
    struct StakeInfo {
        uint256 amount; // Amount staked
        uint256 rewardDebt; // Reward debt
        uint256 lastStakeTime; // Last time user staked or claimed
    }

    mapping(address => StakeInfo) public stakes;
    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public constant REWARD_PRECISION = 1e18;

    // Liquidity Pool Integration (QuickSwap V3 on Polygon)
    address public constant UNISWAP_V3_FACTORY = 0x411b0fAcC3489691f28ad58c47006AF5E3Ab3A28;
    address public constant NONFUNGIBLE_POSITION_MANAGER = 0x8eF88E4c7CfbbaC1C163f7eddd4B578792201de6;
    address public constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    uint24 public constant POOL_FEE = 3000; // 0.3% fee tier
    address public liquidityPool; // PORK/WMATIC pool address
    bool public isPORKToken0; // Cache token order (PORK < WMATIC)
    uint256[] public liquidityPositionIds; // Array of NFT position IDs

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    event MetadataUpdated(string uri);
    event LiquidityPoolCreated(address pool);
    event LiquidityAdded(uint256 tokenId, uint128 liquidity, uint256 amountPORK, uint256 amountMATIC);

    constructor(
        address _multisig,
        string memory _metadataURI
    ) ERC20("Porkelon Token", "PORK") ERC20Permit("Porkelon Token") {
        multisig = _multisig;
        metadataURI = _metadataURI;
        _grantRole(DEFAULT_ADMIN_ROLE, _multisig);
        _grantRole(MINTER_ROLE, _multisig);
        _grantRole(PAUSER_ROLE, _multisig);
        lastUpdateTime = block.timestamp;

        // Pre-approve Position Manager for PORK and WMATIC (max approval)
        IERC20(address(this)).approve(NONFUNGIBLE_POSITION_MANAGER, type(uint256).max);
        IERC20(WMATIC).approve(NONFUNGIBLE_POSITION_MANAGER, type(uint256).max);
    }

    // --- Staking Functions (Unchanged) ---

    function _updateRewards() internal {
        if (totalStaked == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }
        uint256 timeDelta = block.timestamp - lastUpdateTime;
        uint256 reward = timeDelta * rewardRate;
        rewardPerTokenStored += (reward * REWARD_PRECISION) / totalStaked;
        lastUpdateTime = block.timestamp;
    }

    function pendingRewards(address user) public view returns (uint256) {
        StakeInfo storage stake = stakes[user];
        if (stake.amount == 0) return 0;
        uint256 accumulated = rewardPerTokenStored +
            ((block.timestamp - lastUpdateTime) * rewardRate * REWARD_PRECISION) / totalStaked;
        return ((stake.amount * accumulated) / REWARD_PRECISION) - stake.rewardDebt;
    }

    function stake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");
        _updateRewards();
        StakeInfo storage stakeInfo = stakes[msg.sender];
        uint256 pending = pendingRewards(msg.sender);
        if (pending > 0) {
            _transfer(address(this), msg.sender, pending);
            emit RewardsClaimed(msg.sender, pending);
        }
        _transfer(msg.sender, address(this), amount);
        stakeInfo.amount += amount;
        stakeInfo.rewardDebt = (stakeInfo.amount * rewardPerTokenStored) / REWARD_PRECISION;
        stakeInfo.lastStakeTime = block.timestamp;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.amount >= amount, "Insufficient staked amount");
        _updateRewards();
        uint256 pending = pendingRewards(msg.sender);
        if (pending > 0) {
            _transfer(address(this), msg.sender, pending);
            emit RewardsClaimed(msg.sender, pending);
        }
        stakeInfo.amount -= amount;
        stakeInfo.rewardDebt = (stakeInfo.amount * rewardPerTokenStored) / REWARD_PRECISION;
        totalStaked -= amount;
        _transfer(address(this), msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external whenNotPaused {
        _updateRewards();
        uint256 pending = pendingRewards(msg.sender);
        require(pending > 0, "No rewards to claim");
        stakes[msg.sender].rewardDebt = (stakes[msg.sender].amount * rewardPerTokenStored) / REWARD_PRECISION;
        _transfer(address(this), msg.sender, pending);
        emit RewardsClaimed(msg.sender, pending);
    }

    function setRewardRate(uint256 newRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateRewards();
        rewardRate = newRate;
        emit RewardRateUpdated(newRate);
    }

    function fundRewards(uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(address(this), amount);
    }

    // --- Optimized Liquidity Pool Functions ---

    // Create PORK/WMATIC pool if it doesn't exist
    function createLiquidityPool() external onlyRole(DEFAULT_ADMIN_ROLE) returns (address pool) {
        // Check if pool already exists to avoid redundant creation
        pool = IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool(address(this), WMATIC, POOL_FEE);
        if (pool == address(0)) {
            pool = IUniswapV3Factory(UNISWAP_V3_FACTORY).createPool(address(this), WMATIC, POOL_FEE);
            isPORKToken0 = address(this) < WMATIC;
            liquidityPool = pool;
            emit LiquidityPoolCreated(pool);
        } else {
            // Pool exists, cache token order if not set
            if (liquidityPool == address(0)) {
                isPORKToken0 = address(this) < WMATIC;
                liquidityPool = pool;
                emit LiquidityPoolCreated(pool);
            }
        }
        return pool;
    }

    // Add liquidity to PORK/WMATIC pool
    function addLiquidity(
        uint256 amountPORKDesired,
        uint256 amountMATICDesired,
        int24 tickLower,
        int24 tickUpper,
        uint256 deadline
    ) external payable onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        require(liquidityPool != address(0), "Pool not created");
        require(msg.value >= amountMATICDesired, "Insufficient MATIC sent");

        // Wrap MATIC to WMATIC
        if (msg.value > 0) {
            IWMATIC(WMATIC).deposit{value: msg.value}();
        }

        // Prepare mint parameters using cached token order
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: isPORKToken0 ? address(this) : WMATIC,
            token1: isPORKToken0 ? WMATIC : address(this),
            fee: POOL_FEE,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: isPORKToken0 ? amountPORKDesired : amountMATICDesired,
            amount1Desired: isPORKToken0 ? amountMATICDesired : amountPORKDesired,
            amount0Min: 0, // Remove min amounts for simplicity (rely on deadline)
            amount1Min: 0,
            recipient: address(this), // Contract holds LP NFT
            deadline: deadline
        });

        // Mint liquidity position
        (uint256 tokenId, uint128 liquidity, , ) = INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER).mint(params);
        liquidityPositionIds.push(tokenId);
        emit LiquidityAdded(tokenId, liquidity, amountPORKDesired, amountMATICDesired);

        // Refund excess MATIC if any
        if (msg.value > amountMATICDesired) {
            (bool success, ) = msg.sender.call{value: msg.value - amountMATICDesired}("");
            require(success, "Refund failed");
        }
    }

    // View function to get all liquidity position IDs
    function getLiquidityPositionIds() external view returns (uint256[] memory) {
        return liquidityPositionIds;
    }

    // --- Bridge and Other Functions ---

    function mint(
        address to,
        uint256 amount,
        bytes32 payloadHash,
        bytes[] calldata signatures,
        bytes32 nonce
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(!usedNonces[nonce], "Nonce already used");
        usedNonces[nonce] = true;
        require(verifySignatures(payloadHash, signatures), "Invalid signatures");
        _mint(to, amount);
    }

    function airdrop(
        address[] calldata recipients,
        uint256[] calldata amounts,
        bytes32 payloadHash,
        bytes[] calldata signatures,
        bytes32 nonce
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(recipients.length == amounts.length, "Array length mismatch");
        require(!usedNonces[nonce], "Nonce already used");
        usedNonces[nonce] = true;
        require(verifySignatures(payloadHash, signatures), "Invalid signatures");
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }

    function burn(uint256 amount) public override whenNotPaused {
        super.burn(amount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setMetadata(string calldata uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        metadataURI = uri;
        emit MetadataUpdated(uri);
    }

    function verifySignatures(bytes32 payloadHash, bytes[] calldata signatures) private view returns (bool) {
        return signatures.length >= 2; // Replace with actual Gnosis Safe verification
    }

    receive() external payable {}
}
