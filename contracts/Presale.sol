// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Presale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;   // New PORK token on Polygon (ERC-20)
    IERC20 public immutable usdt;    // USDT (or stable) token used for purchases
    address public fundsWallet;      // Where collected MATIC/USDT are forwarded

    uint256 public maticRate; // number of token base units per 1 MATIC (token has decimals)
    uint256 public usdtRate;  // number of token base units per 1 USDT (USDT has 6 decimals usually)
    uint256 public cap;       // total tokens allocated for presale (in token base units)
    uint256 public tokensSold; // in token base units

    uint256 public startTime;
    uint256 public endTime;
    bool public presaleActive;

    uint256 public minPurchaseMatic; // minimum MATIC per tx (wei)
    uint256 public maxPurchaseMatic; // maximum MATIC per tx (wei)
    uint256 public perWalletCap;     // max tokens a wallet can buy total (base units)

    mapping(address => uint256) public purchased; // per-wallet purchased tokens (base units)

    event PresaleStarted(uint256 startTime, uint256 endTime);
    event PresaleEnded(uint256 timestamp);
    event BoughtWithMatic(address indexed buyer, uint256 maticAmount, uint256 tokenAmount);
    event BoughtWithUSDT(address indexed buyer, uint256 usdtAmount, uint256 tokenAmount);
    event EmergencyWithdraw(address indexed to, uint256 amount);
    event ERC20Withdraw(address indexed token, address indexed to, uint256 amount);

    constructor(
        address _token,
        address _usdt,
        address _fundsWallet,
        uint256 _maticRate,
        uint256 _usdtRate,
        uint256 _cap,
        uint256 _minPurchaseMatic,
        uint256 _maxPurchaseMatic,
        uint256 _perWalletCap
    ) {
        require(_token != address(0), "token=0");
        require(_usdt != address(0), "usdt=0");
        require(_fundsWallet != address(0), "funds=0");
        require(_maticRate > 0 && _usdtRate > 0, "rate>0");
        require(_cap > 0, "cap>0");

        token = IERC20(_token);
        usdt = IERC20(_usdt);
        fundsWallet = _fundsWallet;

        maticRate = _maticRate;
        usdtRate = _usdtRate;
        cap = _cap;

        minPurchaseMatic = _minPurchaseMatic;
        maxPurchaseMatic = _maxPurchaseMatic;
        perWalletCap = _perWalletCap;

        presaleActive = false;
    }

    modifier onlyWhileActive() {
        require(presaleActive && block.timestamp >= startTime && block.timestamp <= endTime, "presale not active");
        _;
    }

    // Owner can start presale and set times
    function startPresale(uint256 _startTime, uint256 _endTime) external onlyOwner {
        require(_startTime >= block.timestamp, "start in past");
        require(_endTime > _startTime, "end <= start");
        startTime = _startTime;
        endTime = _endTime;
        presaleActive = true;
        emit PresaleStarted(_startTime, _endTime);
    }

    // Owner may stop the presale early
    function endPresale() external onlyOwner {
        presaleActive = false;
        emit PresaleEnded(block.timestamp);
    }

    // Update fund wallet if needed
    function setFundsWallet(address _fundsWallet) external onlyOwner {
        require(_fundsWallet != address(0), "funds=0");
        fundsWallet = _fundsWallet;
    }

    // Update rates (in base token units per 1 unit of currency)
    function setRates(uint256 _maticRate, uint256 _usdtRate) external onlyOwner {
        require(_maticRate > 0 && _usdtRate > 0, "rate>0");
        maticRate = _maticRate;
        usdtRate = _usdtRate;
    }

    // Buy tokens with native MATIC
    function buyWithMatic() external payable nonReentrant onlyWhileActive {
        uint256 maticAmount = msg.value;
        require(maticAmount >= minPurchaseMatic, "below min matic");
        require(maticAmount <= maxPurchaseMatic, "above max matic");

        uint256 tokenAmount = (maticAmount * maticRate) / 1 ether;
        require(tokenAmount > 0, "token amount 0");
        require(tokensSold + tokenAmount <= cap, "cap exceeded");
        require(token.balanceOf(address(this)) >= tokenAmount, "contract insufficient tokens");
        require(purchased[msg.sender] + tokenAmount <= perWalletCap, "per-wallet cap");

        tokensSold += tokenAmount;
        purchased[msg.sender] += tokenAmount;

        token.safeTransfer(msg.sender, tokenAmount);

        (bool sent, ) = fundsWallet.call{value: maticAmount}("");
        require(sent, "matic transfer failed");

        emit BoughtWithMatic(msg.sender, maticAmount, tokenAmount);
    }

    // Buy tokens with USDT (must approve first)
    function buyWithUSDT(uint256 usdtAmount) external nonReentrant onlyWhileActive {
        require(usdtAmount > 0, "usdt zero");

        uint256 tokenAmount = (usdtAmount * usdtRate) / (10**6);
        require(tokenAmount > 0, "token amount 0");
        require(tokensSold + tokenAmount <= cap, "cap exceeded");
        require(token.balanceOf(address(this)) >= tokenAmount, "contract insufficient tokens");
        require(purchased[msg.sender] + tokenAmount <= perWalletCap, "per-wallet cap");

        tokensSold += tokenAmount;
        purchased[msg.sender] += tokenAmount;

        usdt.safeTransferFrom(msg.sender, fundsWallet, usdtAmount);

        token.safeTransfer(msg.sender, tokenAmount);

        emit BoughtWithUSDT(msg.sender, usdtAmount, tokenAmount);
    }

    // Owner can withdraw any leftover native MATIC (emergency)
    function emergencyWithdraw() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "no matic to withdraw");
        (bool sent, ) = owner().call{value: bal}("");
        require(sent, "withdraw failed");
        emit EmergencyWithdraw(owner(), bal);
    }

    // Owner can withdraw ERC20 tokens accidentally sent to contract (including token after migration finalize)
    function withdrawERC20(address erc20, address to) external onlyOwner {
        require(to != address(0), "to=0");
        IERC20 erc = IERC20(erc20);
        uint256 bal = erc.balanceOf(address(this));
        require(bal > 0, "no token");
        SafeERC20.safeTransfer(erc, to, bal);
        emit ERC20Withdraw(erc20, to, bal);
    }

    // View helper: how many tokens you'd get for given MATIC wei
    function previewTokensForMatic(uint256 maticWei) external view returns (uint256) {
        return (maticWei * maticRate) / 1 ether;
    }

    // View helper: how many tokens you'd get for given USDT base units (assumes 6 decimals)
    function previewTokensForUSDT(uint256 usdtBase) external view returns (uint256) {
        return (usdtBase * usdtRate) / (10**6);
    }

    receive() external payable {}
    fallback() external payable {}
}
