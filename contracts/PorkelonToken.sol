// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PorkelonToken
 * @dev ERC20 token with owner minting, holder burning, and a transfer fee routed to a marketing wallet.
 * Initial supply: 60,000,000,000 * (10 ** 18) minted to deployer.
 */
contract PorkelonToken is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 60_000_000_000 * 10 ** 18;

    // fee in basis points (bps). 100 bps = 1%.
    uint256 public feeBps = 100; // default 1%
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_BPS = 500; // safety cap: 5%

    address public marketingWallet;

    mapping(address => bool) public isExcludedFromFee;

    event MarketingWalletChanged(address indexed previous, address indexed current);
    event FeeBpsChanged(uint256 previous, uint256 current);
    event ExcludeFromFee(address indexed account, bool excluded);

    constructor(address _marketingWallet) ERC20("Porkelon Token", "PORK") {
        require(_marketingWallet != address(0), "marketing cannot be zero");
        marketingWallet = _marketingWallet;

        // mint initial supply to deployer (owner)
        _mint(msg.sender, INITIAL_SUPPLY);

        // default exemptions
        isExcludedFromFee[msg.sender] = true;
        isExcludedFromFee[_marketingWallet] = true;
        isExcludedFromFee[address(this)] = true;
    }

    /** Owner functions **/
    function setMarketingWallet(address _marketingWallet) external onlyOwner {
        require(_marketingWallet != address(0), "marketing cannot be zero");
        address previous = marketingWallet;
        marketingWallet = _marketingWallet;
        emit MarketingWalletChanged(previous, _marketingWallet);
        // auto-exclude
        isExcludedFromFee[_marketingWallet] = true;
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= MAX_FEE_BPS, "fee too high");
        uint256 previous = feeBps;
        feeBps = _feeBps;
        emit FeeBpsChanged(previous, _feeBps);
    }

    function setExcludedFromFee(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
        emit ExcludeFromFee(account, excluded);
    }

    /** Mint & Burn **/
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = allowance(account, msg.sender);
        require(currentAllowance >= amount, "ERC20: burn exceeds allowance");
        _approve(account, msg.sender, currentAllowance - amount);
        _burn(account, amount);
    }

    /** Override _transfer to include fee logic **/
    function _transfer(address from, address to, uint256 amount) internal override {
        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        // skip fee for excluded addresses or zero fee
        if (isExcludedFromFee[from] || isExcludedFromFee[to] || feeBps == 0) {
            super._transfer(from, to, amount);
        } else {
            uint256 fee = (amount * feeBps) / FEE_DENOMINATOR;
            uint256 afterFee = amount - fee;

            if (fee > 0 && marketingWallet != address(0)) {
                super._transfer(from, marketingWallet, fee);
            }

            super._transfer(from, to, afterFee);
        }
    }
}
