// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Porkelon.sol"; // or IERC20 interface

interface IUniswapV2Router {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract PorkelonPresale is Ownable, ReentrancyGuard {
    Porkelon public token;
    IUniswapV2Router public router;
    address public liquidityReceiver; // where LP tokens are sent (or this contract)
    bytes32 public merkleRoot; // optional whitelist
    bool public whitelistEnabled;

    uint256 public presaleStart;
    uint256 public presaleEnd;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public raised;
    uint256 public minContribution;
    uint256 public maxContribution;
    uint256 public presaleRate; // tokens per 1 ETH (no decimals)
    uint256 public liquidityPercent; // e.g. 60 = 60%

    mapping(address => uint256) public contributions;
    bool public finalized;
    bool public cancelled;

    event Contributed(address indexed user, uint256 amount);
    event Finalized(uint256 raised, bool success);
    event Refunded(address indexed user, uint256 amount);

    constructor(
        address _token,
        address _router,
        address _liquidityReceiver,
        uint256 _presaleStart,
        uint256 _presaleEnd,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _minContribution,
        uint256 _maxContribution,
        uint256 _presaleRate,
        uint256 _liquidityPercent
    ){
        require(_token != address(0) && _router != address(0) && _liquidityReceiver != address(0), "zero addr");
        require(_presaleStart < _presaleEnd, "invalid time");
        token = Porkelon(_token);
        router = IUniswapV2Router(_router);
        liquidityReceiver = _liquidityReceiver;
        presaleStart = _presaleStart;
        presaleEnd = _presaleEnd;
        softCap = _softCap;
        hardCap = _hardCap;
        minContribution = _minContribution;
        maxContribution = _maxContribution;
        presaleRate = _presaleRate;
        liquidityPercent = _liquidityPercent;
    }

    receive() external payable {
        buy(msg.sender, bytes32(0), new bytes32); // fallback if whitelist disabled
    }

    function setWhitelist(bytes32 _merkleRoot, bool enabled) external onlyOwner {
        merkleRoot = _merkleRoot;
        whitelistEnabled = enabled;
    }

    function buy(address beneficiary, bytes32 leaf, bytes32[] calldata proof) public payable nonReentrant {
        require(block.timestamp >= presaleStart && block.timestamp <= presaleEnd, "not active");
        require(!cancelled, "cancelled");
        if (whitelistEnabled) {
            bytes32 node = keccak256(abi.encodePacked(beneficiary));
            require(MerkleProof.verify(proof, merkleRoot, node), "not whitelisted");
        }
        uint256 amount = msg.value;
        require(amount >= minContribution && contributions[beneficiary] + amount <= maxContribution, "bad contrib");

        require(raised + amount <= hardCap, "exceeds hard cap");
        contributions[beneficiary] += amount;
        raised += amount;
        emit Contributed(beneficiary, amount);
    }

    // If presale fails or owner cancels
    function claimRefund() external nonReentrant {
        require(block.timestamp > presaleEnd || cancelled, "not ended");
        require(raised < softCap || cancelled, "successful");
        uint256 contributed = contributions[msg.sender];
        require(contributed > 0, "no contribution");
        contributions[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: contributed}("");
        require(ok, "refund failed");
        emit Refunded(msg.sender, contributed);
    }

    // finalize: if success, add liquidity and enable token distribution
    function finalize(uint256 tokenAmountForPresale) external onlyOwner nonReentrant {
        require(!finalized, "done");
        require(block.timestamp > presaleEnd, "not ended");
        require(raised >= softCap, "softcap not reached");
        finalized = true;

        uint256 ethForLiquidity = (raised * liquidityPercent) / 100;
        uint256 tokenForLiquidity = (tokenAmountForPresale * liquidityPercent) / 100;
        uint256 tokenForDistribution = tokenAmountForPresale - tokenForLiquidity;

        // Transfer tokens from owner to this contract: owner must approve token transfer OR transfer token first
        // Owner should transfer tokenAmountForPresale tokens to this contract prior to calling finalize.
        // Add liquidity
        token.approve(address(router), tokenForLiquidity);

        router.addLiquidityETH{value: ethForLiquidity}(
            address(token),
            tokenForLiquidity,
            0,
            0,
            liquidityReceiver,
            block.timestamp + 3600
        );

        // distribute tokens to contributors
        // For gas reasons, distribution may be done via claim() per user or batched offchain. We'll implement claim logic.
        emit Finalized(raised, true);
    }

    // After finalize, contributors call claimTokens to get their allocation
    function claimTokens() external nonReentrant {
        require(finalized, "not finalized");
        uint256 contributed = contributions[msg.sender];
        require(contributed > 0, "no contribution");
        contributions[msg.sender] = 0;
        uint256 tokensToSend = (contributed * presaleRate);
        require(token.balanceOf(address(this)) >= tokensToSend, "insufficient tokens in contract");
        token.transfer(msg.sender, tokensToSend);
    }

    // Owner utilities
    function cancelPresale() external onlyOwner {
        require(!finalized, "already finalized");
        cancelled = true;
    }

    // Withdraw leftover ETH (owner fees, marketing) after finalize
    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        require(finalized, "not finalized");
        require(to != address(0), "zero addr");
        (bool ok,) = to.call{value: amount}("");
        require(ok, "withdraw failed");
    }

    // emergency withdraw tokens owned by contract (only owner)
    function emergencyWithdrawToken(address tokenAddr, address to) external onlyOwner {
        IERC20(tokenAddr).transfer(to, IERC20(tokenAddr).balanceOf(address(this)));
    }
}
