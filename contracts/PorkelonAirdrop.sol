// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PorkelonAirdrop
 * @dev Manages airdrop distribution of PORK tokens on Polygon.
 *      Only the owner can trigger batch airdrops from the allocated pool.
 */
contract PorkelonAirdrop is Ownable {
    IERC20 public token; // PORK token (Porkelon)
    uint256 public airdropPool; // Available tokens for airdrop

    event AirdropSent(address indexed recipient, uint256 amount);

    /**
     * @dev Constructor sets the token and initial airdrop pool.
     * @param _token Address of the PORK token contract.
     * @param _airdropPool Amount of tokens allocated for airdrops.
     */
    constructor(IERC20 _token, uint256 _airdropPool) Ownable(msg.sender) {
        require(address(_token) != address(0), "Invalid token address");
        token = _token;
        airdropPool = _airdropPool;
    }

    /**
     * @dev Distributes tokens to multiple recipients in a batch.
     *      Only callable by the owner.
     * @param recipients Array of recipient addresses.
     * @param amounts Array of token amounts to send (in wei).
     */
    function airdropBatch(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Array length mismatch");
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        require(total <= airdropPool, "Insufficient airdrop funds");

        airdropPool -= total;
        for (uint256 i = 0; i < recipients.length; i++) {
            if (amounts[i] > 0) {
                require(token.transfer(recipients[i], amounts[i]), "Transfer failed");
                emit AirdropSent(recipients[i], amounts[i]);
            }
        }
    }
}
