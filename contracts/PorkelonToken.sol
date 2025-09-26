// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PorkelonToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public constant DEV_WALLET = 0xBc2E051f3Dedcd0B9dDCA2078472f513a37df2C6;
    address public liquidityWallet;
    address public feeWallet;
    address public marketingWallet;

    uint256 public constant FEE_PERCENT = 1;
    mapping(address => bool) public excludedFromFee;

    uint256 private constant DECIMALS = 18;
    uint256 private constant DECIMAL_FACTOR = 10**DECIMALS;
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000 * DECIMAL_FACTOR;

    event FeeCollected(address indexed from, address indexed to, uint256 fee);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _liquidityWallet, address _marketingWallet) public initializer {
        require(_liquidityWallet != address(0) && _marketingWallet != address(0), "Zero address");

        __ERC20_init("Porkelon", "PORK");
        __ERC20Burnable_init();
        __Pausable_init();
        __Ownable_init(DEV_WALLET);
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        liquidityWallet = _liquidityWallet;
        marketingWallet = _marketingWallet;
        feeWallet = DEV_WALLET;

        _mint(address(this), TOTAL_SUPPLY);

        excludedFromFee[address(this)] = true;
        excludedFromFee[DEV_WALLET] = true;
        excludedFromFee[_liquidityWallet] = true;
        excludedFromFee[_marketingWallet] = true;
        excludedFromFee[feeWallet] = true;

        _grantRole(DEFAULT_ADMIN_ROLE, DEV_WALLET);
        _grantRole(PAUSER_ROLE, DEV_WALLET);
        _grantRole(UPGRADER_ROLE, DEV_WALLET);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable, PausableUpgradeable) {
        require(!paused(), "Token: paused");
        if (from == address(0) || to == address(0) || excludedFromFee[from] || excludedFromFee[to]) {
            super._update(from, to, value);
        } else {
            uint256 fee = (value * FEE_PERCENT) / 100;
            uint256 net = value - fee;
            super._update(from, feeWallet, fee);
            super._update(from, to, net);
            emit FeeCollected(from, to, fee);
        }
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setExcludedFromFee(address account, bool excluded) external onlyOwner {
        excludedFromFee[account] = excluded;
    }

    function updateFeeWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero address");
        excludedFromFee[feeWallet] = false;
        feeWallet = newWallet;
        excludedFromFee[newWallet] = true;
    }

    function updateMarketingWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero address");
        excludedFromFee[marketingWallet] = false;
        marketingWallet = newWallet;
        excludedFromFee[newWallet] = true;
    }

    function distributeAllocations(
        address presaleContract,
        address airdropContract,
        address stakingContract,
        address liquidityLocker
    ) external onlyOwner nonReentrant {
        require(
            presaleContract != address(0) &&
            airdropContract != address(0) &&
            stakingContract != address(0) &&
            liquidityLocker != address(0),
            "Zero address"
        );

        uint256 devAmt = (TOTAL_SUPPLY * 25) / 100;
        uint256 stakingAmt = (TOTAL_SUPPLY * 10) / 100;
        uint256 liquidityAmt = (TOTAL_SUPPLY * 40) / 100;
        uint256 marketingAmt = (TOTAL_SUPPLY * 10) / 100;
        uint256 airdropAmt = (TOTAL_SUPPLY * 5) / 100;
        uint256 presaleAmt = (TOTAL_SUPPLY * 10) / 100;

        _transfer(address(this), DEV_WALLET, devAmt);
        _transfer(address(this), marketingWallet, marketingAmt);
        _transfer(address(this), presaleContract, presaleAmt);
        _transfer(address(this), airdropContract, airdropAmt);
        _transfer(address(this), stakingContract, stakingAmt);
        _transfer(address(this), liquidityLocker, liquidityAmt);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    receive() external payable {}
}
