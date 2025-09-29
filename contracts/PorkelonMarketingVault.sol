// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract PorkelonMarketingVault is Ownable, Pausable {
    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable startTime;
    uint256 public immutable duration;
    uint256 public released;

    uint256 public constant RELEASE_DELAY = 1 days;
    uint256 public proposedReleaseTimestamp;
    uint256 public proposedAmount;

    event TokensReleased(address indexed recipient, uint256 amount);
    event ReleaseProposed(uint256 amount, uint256 timestamp);

    constructor(IERC20 _token, address _beneficiary, uint256 _duration) Ownable(msg.sender) {
        require(address(_token) != address(0), "Invalid token address");
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_duration > 0, "Invalid duration");

        token = _token;
        beneficiary = _beneficiary;
        startTime = block.timestamp;
        duration = _duration;
    }

    function proposeRelease(uint256 amount) external onlyOwner whenNotPaused {
        require(amount <= vestedAmount() - released, "Exceeds releasable amount");
        proposedAmount = amount;
        proposedReleaseTimestamp = block.timestamp;
        emit ReleaseProposed(amount, block.timestamp);
    }

    function release() external onlyOwner whenNotPaused {
        require(proposedReleaseTimestamp > 0 && block.timestamp >= proposedReleaseTimestamp + RELEASE_DELAY, "Timelock not elapsed");
        uint256 releasable = proposedAmount;
        require(releasable > 0, "No tokens to release");
        require(token.balanceOf(address(this)) >= releasable, "Insufficient token balance");
        released += releasable;
        proposedAmount = 0;
        proposedReleaseTimestamp = 0;
        require(token.transfer(beneficiary, releasable), "Transfer failed");
        emit TokensReleased(beneficiary, releasable);
    }

    function releaseToStaking(address stakingContract) external onlyOwner whenNotPaused {
        require(stakingContract != address(0), "Invalid staking contract");
        require(proposedReleaseTimestamp > 0 && block.timestamp >= proposedReleaseTimestamp + RELEASE_DELAY, "Timelock not elapsed");
        uint256 releasable = proposedAmount;
        require(releasable > 0, "No tokens to release");
        require(token.balanceOf(address(this)) >= releasable, "Insufficient token balance");
        released += releasable;
        proposedAmount = 0;
        proposedReleaseTimestamp = 0;
        require(token.approve(stakingContract, releasable), "Approval failed");
        emit TokensReleased(stakingContract, releasable);
    }

    function releaseBatch(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner whenNotPaused {
        require(recipients.length == amounts.length, "Array length mismatch");
        uint256 totalReleasable = vestedAmount() - released;
        uint256 totalToRelease;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalToRelease += amounts[i];
        }
        require(totalToRelease <= totalReleasable, "Exceeds releasable amount");
        require(token.balanceOf(address(this)) >= totalToRelease, "Insufficient token balance");
        released += totalToRelease;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient");
            require(token.transfer(recipients[i], amounts[i]), "Transfer failed");
            emit TokensReleased(recipients[i], amounts[i]);
        }
    }

    function vestedAmount() public view returns (uint256) {
        uint256 totalBalance = token.balanceOf(address(this)) + released;
        if (block.timestamp < startTime) {
            return 0;
        } else if (block.timestamp >= startTime + duration) {
            return totalBalance;
        }
        return (totalBalance * (block.timestamp - startTime)) / duration;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
