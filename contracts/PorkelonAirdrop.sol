// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PorkelonAirdrop
 * @dev Manages airdrop distribution of PORK tokens.
 */
contract PorkelonAirdrop is Ownable {
    IERC20 public token;
    uint256 public airdropPool;

    event AirdropSent(address indexed recipient, uint256 amount);

    constructor(IERC20 _token, uint256 _airdropPool) Ownable(msg.sender) {
        token = _token;
        airdropPool = _airdropPool;
    }

    function airdropBatch(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Length mismatch");
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        require(total <= airdropPool, "Not enough airdrop funds");

        airdropPool -= total;
        for (uint256 i = 0; i < recipients.length; i++) {
            if (amounts[i] > 0) {
                require(token.transfer(recipients[i], amounts[i]), "Transfer failed");
                emit AirdropSent(recipients[i], amounts[i]);
            }
        }
    }
}
