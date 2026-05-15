// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * ╔═══════════════════════════════════════════════════════════╗
 * ║          CMVNG SIGNALVAULT — SUBSCRIPTION CONTRACT        ║
 * ║          Arc Testnet · USDC Payments · 4 Tiers            ║
 * ╚═══════════════════════════════════════════════════════════╝
 *
 * Deploy on Arc Testnet:
 *   - RPC:      https://rpc.testnet.arc.network
 *   - Chain ID: 5042002
 *   - USDC:     Native token (also accessible via ERC-20 interface)
 *   - Faucet:   https://faucet.circle.com
 *
 * Tiers:
 *   1 = Pro         (15 USDC/month)
 *   2 = Elite       (50 USDC/month)
 *   3 = Institutional (150 USDC/month)
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CmvngSignalVault is Ownable, ReentrancyGuard {

    // ─── State ───────────────────────────────────────────────

    IERC20 public immutable usdc;

    struct Subscription {
        uint8   tier;          // 1=Pro, 2=Elite, 3=Institutional
        uint256 expiresAt;
        uint256 totalPaid;
        string  telegramUserId;
    }

    mapping(address => Subscription) public subscriptions;
    mapping(uint8 => uint256)        public tierPrices;   // tier => price in USDC (6 decimals)

    uint256 public constant DURATION = 30 days;

    // ─── Events ──────────────────────────────────────────────

    event Subscribed(
        address indexed wallet,
        uint8   tier,
        uint256 amount,
        uint256 expiresAt,
        string  telegramUserId
    );

    event Renewed(
        address indexed wallet,
        uint8   tier,
        uint256 amount,
        uint256 newExpiresAt,
        string  telegramUserId
    );

    event Upgraded(
        address indexed wallet,
        uint8   oldTier,
        uint8   newTier,
        uint256 amount,
        uint256 expiresAt,
        string  telegramUserId
    );

    event TierPriceUpdated(uint8 tier, uint256 oldPrice, uint256 newPrice);

    event Withdrawn(address indexed to, uint256 amount);

    // ─── Constructor ─────────────────────────────────────────

    /**
     * @param _usdc Address of the USDC ERC-20 contract on Arc Testnet.
     *              On Arc, USDC is native but also has an ERC-20 interface.
     *              Check https://docs.arc.network/arc/references/contract-addresses
     */
    constructor(address _usdc) Ownable(msg.sender) {
        usdc = IERC20(_usdc);

        // Prices in USDC with 6 decimals
        tierPrices[1] =  15 * 1e6;   // Pro:            15 USDC
        tierPrices[2] =  50 * 1e6;   // Elite:          50 USDC
        tierPrices[3] = 150 * 1e6;   // Institutional: 150 USDC
    }

    // ─── Core Functions ──────────────────────────────────────

    /**
     * @notice Subscribe to a tier. First-time or expired users.
     * @param _tier            1=Pro, 2=Elite, 3=Institutional
     * @param _telegramUserId  User's Telegram numeric ID (string)
     */
    function subscribe(uint8 _tier, string calldata _telegramUserId) external nonReentrant {
        require(_tier >= 1 && _tier <= 3, "Invalid tier");
        require(bytes(_telegramUserId).length > 0, "Telegram ID required");

        uint256 price = tierPrices[_tier];
        require(price > 0, "Tier not configured");

        // Transfer USDC from user to contract
        require(usdc.transferFrom(msg.sender, address(this), price), "Payment failed");

        uint256 expiry = block.timestamp + DURATION;

        subscriptions[msg.sender] = Subscription({
            tier:           _tier,
            expiresAt:      expiry,
            totalPaid:      subscriptions[msg.sender].totalPaid + price,
            telegramUserId: _telegramUserId
        });

        emit Subscribed(msg.sender, _tier, price, expiry, _telegramUserId);
    }

    /**
     * @notice Renew current tier. Extends from current expiry if still active,
     *         or from now if expired.
     */
    function renew() external nonReentrant {
        Subscription storage sub = subscriptions[msg.sender];
        require(sub.tier > 0, "No subscription found");

        uint256 price = tierPrices[sub.tier];
        require(usdc.transferFrom(msg.sender, address(this), price), "Payment failed");

        // If still active, extend from current expiry. If expired, start from now.
        uint256 base = sub.expiresAt > block.timestamp ? sub.expiresAt : block.timestamp;
        sub.expiresAt = base + DURATION;
        sub.totalPaid += price;

        emit Renewed(msg.sender, sub.tier, price, sub.expiresAt, sub.telegramUserId);
    }

    /**
     * @notice Upgrade to a higher tier. Pays the full new tier price and
     *         resets the 30-day window.
     * @param _newTier  Must be higher than current tier.
     */
    function upgrade(uint8 _newTier) external nonReentrant {
        Subscription storage sub = subscriptions[msg.sender];
        require(sub.tier > 0, "No subscription found");
        require(_newTier > sub.tier && _newTier <= 3, "Must upgrade to a higher tier");

        uint256 price = tierPrices[_newTier];
        require(usdc.transferFrom(msg.sender, address(this), price), "Payment failed");

        uint8 oldTier = sub.tier;
        sub.tier = _newTier;
        sub.expiresAt = block.timestamp + DURATION;
        sub.totalPaid += price;

        emit Upgraded(msg.sender, oldTier, _newTier, price, sub.expiresAt, sub.telegramUserId);
    }

    // ─── View Functions ──────────────────────────────────────

    /**
     * @notice Check if a wallet has an active subscription.
     */
    function isActive(address _user) external view returns (bool) {
        return subscriptions[_user].expiresAt > block.timestamp;
    }

    /**
     * @notice Get the tier of an active subscriber. Returns 0 if expired.
     */
    function activeTier(address _user) external view returns (uint8) {
        if (subscriptions[_user].expiresAt > block.timestamp) {
            return subscriptions[_user].tier;
        }
        return 0;
    }

    /**
     * @notice Get full subscription info.
     */
    function getSubscription(address _user) external view returns (
        uint8   tier,
        uint256 expiresAt,
        uint256 totalPaid,
        string memory telegramUserId,
        bool    active
    ) {
        Subscription memory sub = subscriptions[_user];
        return (
            sub.tier,
            sub.expiresAt,
            sub.totalPaid,
            sub.telegramUserId,
            sub.expiresAt > block.timestamp
        );
    }

    // ─── Admin ───────────────────────────────────────────────

    /**
     * @notice Update tier pricing. Only owner.
     */
    function setTierPrice(uint8 _tier, uint256 _price) external onlyOwner {
        require(_tier >= 1 && _tier <= 3, "Invalid tier");
        uint256 old = tierPrices[_tier];
        tierPrices[_tier] = _price;
        emit TierPriceUpdated(_tier, old, _price);
    }

    /**
     * @notice Withdraw collected USDC to owner wallet.
     */
    function withdraw() external onlyOwner {
        uint256 balance = usdc.balanceOf(address(this));
        require(balance > 0, "Nothing to withdraw");
        require(usdc.transfer(owner(), balance), "Withdraw failed");
        emit Withdrawn(owner(), balance);
    }

    /**
     * @notice Withdraw a specific amount.
     */
    function withdrawAmount(uint256 _amount) external onlyOwner {
        require(usdc.balanceOf(address(this)) >= _amount, "Insufficient balance");
        require(usdc.transfer(owner(), _amount), "Withdraw failed");
        emit Withdrawn(owner(), _amount);
    }
}
