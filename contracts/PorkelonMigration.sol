// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IStakingRewards {
    function stake(uint256 amount) external;
}

contract PorkelonMigration is Ownable {
    IERC20 public immutable newToken;
    IStakingRewards public stakingContract;
    bytes32 public merkleRoot;
    mapping(address => bool) public claimed;

    event Claimed(address indexed user, uint256 amount, bool staked);

    constructor(address _newToken, bytes32 _merkleRoot) {
        require(_newToken != address(0), "Zero token");
        newToken = IERC20(_newToken);
        merkleRoot = _merkleRoot;
    }

    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Zero address");
        stakingContract = IStakingRewards(_stakingContract);
    }

    function claim(uint256 amount, bytes32[] calldata proof) external {
        _claim(msg.sender, amount, proof, false);
    }

    function claimAndStake(uint256 amount, bytes32[] calldata proof) external {
        _claim(msg.sender, amount, proof, true);
    }

    function _claim(address user, uint256 amount, bytes32[] calldata proof, bool stake) internal {
        require(!claimed[user], "Already claimed");

        bytes32 leaf = keccak256(abi.encodePacked(user, amount));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");

        claimed[user] = true;
        if (stake) {
            require(address(stakingContract) != address(0), "Staking contract not set");
            require(newToken.approve(address(stakingContract), amount), "Approval failed");
            stakingContract.stake(amount);
        } else {
            require(newToken.transfer(user, amount), "Transfer failed");
        }

        emit Claimed(user, amount, stake);
    }

    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }
}
