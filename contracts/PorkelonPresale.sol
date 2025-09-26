// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PorkelonPresale is Ownable {
    IERC20 public porkToken;
    IERC20 public usdt;  // USDT on Polygon
    address public fundsWallet;  // Where MATIC/USDT go (e.g., team wallet)

    uint256 public maticRate;  // PORK per MATIC (e.g., 1000000 for 1M PORK per MATIC)
    uint256 public usdtRate;   // PORK per USDT
    uint256 public cap;        // Max PORK for presale (e.g., 10B * 10**18)
    uint256 public sold;

    bool public active;

    event Bought(address buyer, uint256 amount, bool withUsdt);

    constructor(
        address _porkToken,
        address _usdt,
        address _fundsWallet,
        uint256 _maticRate,
        uint256 _usdtRate,
        uint256 _cap
    ) Ownable(msg.sender) {
        porkToken = IERC20(_porkToken);
        usdt = IERC20(_usdt);
        fundsWallet = _fundsWallet;
        maticRate = _maticRate;
        usdtRate = _usdtRate;
        cap = _cap;
    }

    function buyWithMatic() external payable {
        require(active, "Presale not active");
        require(msg.value > 0, "No MATIC sent");
        uint256 tokens = msg.value * maticRate;
        require(sold + tokens <= cap, "Presale cap exceeded");
        sold += tokens;
        porkToken.transfer(msg.sender, tokens);
        payable(fundsWallet).transfer(msg.value);
        emit Bought(msg.sender, tokens, false);
    }

    function buyWithUsdt(uint256 usdtAmount) external {
        require(active, "Presale not active");
        require(usdtAmount > 0, "No USDT sent");
        uint256 tokens = usdtAmount * usdtRate;
        require(sold + tokens <= cap, "Presale cap exceeded");
        sold += tokens;
        usdt.transferFrom(msg.sender, fundsWallet, usdtAmount);
        porkToken.transfer(msg.sender, tokens);
        emit Bought(msg.sender, tokens, true);
    }

    function setRates(uint256 _maticRate, uint256 _usdtRate) external onlyOwner {
        maticRate = _maticRate;
        usdtRate = _usdtRate;
    }

    function setActive(bool _active) external onlyOwner {
        active = _active;
    }

    function withdrawRemainingTokens() external onlyOwner {
        uint256 remaining = porkToken.balanceOf(address(this));
        porkToken.transfer(owner(), remaining);
    }
}
