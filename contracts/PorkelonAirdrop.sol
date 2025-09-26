// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title PorkelonAirdrop
 * @dev Manages airdrop distribution of PORK tokens.
 */
contract PorkelonAirdrop is Ownable {
    using SafeMath for uint256;

    IERC20 public immutable token;
    uint256 public airdropPool;

    event AirdropSent(address indexed recipient, uint256 amount);
    event AirdropPoolUpdated(uint256 oldPool, uint256 newPool);

    constructor(IERC20 _token, uint256 _airdropPool) Ownable(msg.sender) {
        require(address(_token) != address(0), "PorkelonAirdrop: Invalid token address");
        require(_airdropPool > 0, "PorkelonAirdrop: Invalid pool size");
        token = _token;
        airdropPool = _airdropPool;
        emit AirdropPoolUpdated(0, _airdropPool);
    }

    function airdropBatch(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "PorkelonAirdrop: Array length mismatch");
        require(recipients.length > 0, "PorkelonAirdrop: Empty arrays");

        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total = total.add(amounts[i]);
        }
        require(total <= airdropPool, "PorkelonAirdrop: Insufficient funds");

        airdropPool = airdropPool.sub(total);
        emit AirdropPoolUpdated(total, airdropPool);

        for (uint256 i = 0; i < recipients.length; i++) {
            if (amounts[i] > 0 && recipients[i] != address(0)) {
                require(token.transfer(recipients[i], amounts[i]), "PorkelonAirdrop: Transfer failed");
                emit AirdropSent(recipients[i], amounts[i]);
            }
        }
    }
}
