// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Porkelon Token (PORK)
/// @notice ERC20 token with configurable transfer fee forwarded to a marketing wallet.
///         Includes owner utilities for managing fees, exclusions, rescuing tokens/ETH,
///         and a hard cap on total supply.
contract PorkelonToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /// @notice Initial supply minted to deployer (18 decimals).
    uint256 public constant INITIAL_SUPPLY = 60_000_000_000 * 10**18;

    /// @notice Maximum total supply (hard cap). Set equal to INITIAL_SUPPLY so supply is fixed.
    /// If you want a different cap that allows future minting, tell me the desired value and I'll update it.
    uint256 public constant MAX_SUPPLY = 60_000_000_000 * 10**18;

    /// @notice Fee in basis points (parts per 10,000). Default 100 = 1%.
    uint16 public feeBps = 100;

    /// @notice Fee denominator for basis points math.
    uint256 public constant FEE_DENOMINATOR = 10_000;

    /// @notice Maximum allowed fee in bps (500 = 5%).
    uint16 public constant MAX_FEE_BPS = 500;

    /// @notice Address that receives collected fees.
    address public marketingWallet;

    /// @notice Addresses excluded from fee mechanism.
    mapping(address => bool) public isExcludedFromFee;

    /* ========== ERRORS ========== */
    error ZeroAddress();
    error FeeTooHigh(uint256 max);
    error InsufficientAllowance();
    error NothingToRescue();
    error MaxSupplyExceeded(uint256 max);

    /* ========== EVENTS ========== */
    event MarketingWalletChanged(address indexed previous, address indexed current);
    event FeeBpsChanged(uint256 previous, uint256 current);
    event ExcludeFromFee(address indexed account, bool excluded);
    event TokensRescued(address indexed token, address indexed to, uint256 amount);
    event EthRescued(address indexed to, uint256 amount);
    event Minted(address indexed to, uint256 amount);

    /* ========== CONSTRUCTOR ========== */

    /// @param _marketingWallet address to receive transfer fees (must be non-zero)
    constructor(address _marketingWallet) ERC20("Porkelon Token", "PORK") {
        if (_marketingWallet == address(0)) revert ZeroAddress();

        marketingWallet = _marketingWallet;

        _mint(_msgSender(), INITIAL_SUPPLY);

        // exclude common system addresses from fees
        isExcludedFromFee[_msgSender()] = true;
        isExcludedFromFee[_marketingWallet] = true;
        isExcludedFromFee[address(this)] = true;
    }

    /* ========== OWNER CONFIGURATION ========== */

    /// @notice Change the marketing wallet that receives collected fees.
    /// @dev New wallet is automatically excluded from fees.
    function setMarketingWallet(address _marketingWallet) external onlyOwner {
        if (_marketingWallet == address(0)) revert ZeroAddress();

        address previous = marketingWallet;
        marketingWallet = _marketingWallet;
        isExcludedFromFee[_marketingWallet] = true;

        emit MarketingWalletChanged(previous, _marketingWallet);
    }

    /// @notice Update the fee in basis points (max MAX_FEE_BPS).
    function setFeeBps(uint16 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh(MAX_FEE_BPS);

        uint256 previous = feeBps;
        feeBps = _feeBps;

        emit FeeBpsChanged(previous, _feeBps);
    }

    /// @notice Include or exclude an account from transfer fees.
    function setExcludedFromFee(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
        emit ExcludeFromFee(account, excluded);
    }

    /// @notice Batch include/exclude accounts from transfer fees to save txs.
    function setExcludedFromFeeBatch(address[] calldata accounts, bool excluded) external onlyOwner {
        uint256 len = accounts.length;
        for (uint256 i = 0; i < len; ) {
            isExcludedFromFee[accounts[i]] = excluded;
            emit ExcludeFromFee(accounts[i], excluded);
            unchecked { ++i; }
        }
    }

    /* ========== MINT / BURN ========== */

    /// @notice Mint tokens. Restricted to owner and constrained by MAX_SUPPLY.
    /// @dev Emits standard ERC20 Transfer from zero address and a Minted event.
    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) return; // nothing to do

        // enforce the hard cap
        if (totalSupply() + amount > MAX_SUPPLY) revert MaxSupplyExceeded(MAX_SUPPLY);

        _mint(to, amount);
        emit Minted(to, amount);
    }

    /// @notice Burn tokens from caller.
    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    /// @notice Burn tokens from an approved allowance.
    /// @dev Decreases allowance with unchecked arithmetic for small gas saving after validation.
    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = allowance(account, _msgSender());
        if (currentAllowance < amount) revert InsufficientAllowance();

        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }

        _burn(account, amount);
    }

    /* ========== FEE HELPERS ========== */

    /// @notice Calculate fee and post-fee amount for a given transfer amount.
    /// @return fee amount to be collected, amount after fee that the recipient receives.
    function feeForAmount(uint256 amount) public view returns (uint256 fee, uint256 afterFee) {
        fee = (amount * feeBps) / FEE_DENOMINATOR;
        afterFee = amount - fee;
    }

    /* ========== CORE TRANSFER OVERRIDE ========== */

    /// @dev If either side is excluded or fee is zero, perform a standard transfer.
    ///      Otherwise deduct fee and forward it to marketingWallet then transfer remainder.
    function _transfer(address from, address to, uint256 amount) internal override {
        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (isExcludedFromFee[from] || isExcludedFromFee[to] || feeBps == 0) {
            super._transfer(from, to, amount);
            return;
        }

        uint256 fee = (amount * feeBps) / FEE_DENOMINATOR;
        if (fee > 0) {
            // marketingWallet validated on constructor/setter to never be zero
            super._transfer(from, marketingWallet, fee);
        }

        uint256 afterFee = amount - fee;
        super._transfer(from, to, afterFee);
    }

    /* ========== RESCUE / RECOVERY ========== */

    /// @notice Rescue ERC20 tokens mistakenly sent to this contract.
    /// @param token ERC20 token to rescue
    /// @param to recipient to receive rescued tokens
    /// @param amount amount to rescue
    function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert NothingToRescue();

        token.safeTransfer(to, amount);
        emit TokensRescued(address(token), to, amount);
    }

    /// @notice Rescue ETH mistakenly sent to this contract.
    function rescueETH(address payable to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert NothingToRescue();

        // solhint-disable-next-line avoid-low-level-calls
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "ETH transfer failed");
        emit EthRescued(to, amount);
    }

    /// @notice Allow contract to receive ETH (for rescue operations or accidental transfers).
    receive() external payable {}
}
