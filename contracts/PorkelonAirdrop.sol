// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PorkelonAirdrop
 * @dev Manages airdrop distribution using a Merkle Tree.
 */
contract PorkelonAirdrop is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    bytes32 public immutable merkleRoot;
    mapping(address => bool) public claimed;

    event Claimed(address indexed user, uint256 amount);

    constructor(address _tokenAddress, bytes32 _merkleRoot) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Airdrop: Invalid token address");
        token = IERC20(_tokenAddress);
        merkleRoot = _merkleRoot;
    }

    function claim(uint256 amount, bytes32[] calldata proof) external {
        require(!claimed[msg.sender], "Airdrop: Already claimed");

        // Verify the user's proof against the Merkle root
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Airdrop: Invalid proof");

        claimed[msg.sender] = true;
        
        // This contract must be funded with the total airdrop supply
        token.safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }
    
    // Safety function for the owner to withdraw any remaining tokens after the airdrop period
    function withdrawUnclaimedTokens() external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }
}
