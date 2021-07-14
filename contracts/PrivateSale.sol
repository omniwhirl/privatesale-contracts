//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PrivateSale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    ERC20 public stable_coin;
    ERC20 public sale_token;
    uint256 public raised_funds;

    bool public isRaiseComplete = false;

    mapping(address => bool) public influencer_whitelist;
    mapping(address => bool) public individual_whitelist;
    mapping(address => bool) public vc_whitelist;

    mapping(address => uint256) public influencer_purchased;
    mapping(address => uint256) public individual_purchased;
    mapping(address => uint256) public vc_purchased;

    mapping(address => Purchase) public purchases;

    struct Purchase {
        uint256 token_amount;
        address purchaser;
        uint256 stable_coin_amount;
        uint256 timestamp;
        string purchase_type;
        bool withdrawn;
    }

    uint256 public constant vc_tokens = 100000; // 10% (TGE emmision) of 100,000 tokens per VC
    uint256 public constant influencer_tokens = 25000; // 10% (TGE emmision) of 25,000 tokens per influencer
    uint256 public constant individual_tokens = 25000; // 10% (TGE emmision) of 25,000 tokens per participant

    uint256 public constant max_vc = 10;
    uint256 public constant max_influencer = 15;
    uint256 public constant max_individual = 25;

    uint256 public vc_purchase_count = 0;
    uint256 public influencer_purchase_count = 0;
    uint256 public individual_purchase_count = 0;

    uint256 exchange_rate_cents = 10; // $0.1
    uint256 TGE_unlock = 10; // 10% unlocked at TGE

    event addedToInfluencerWhitelist(address[] indexed accounts);
    event addedToIndividualWhitelist(address[] indexed accounts);
    event addedToVCWhitelist(address[] indexed accounts);

    event removedFromInfluencerWhitelist(address[] indexed accounts);
    event removedFromIndividualWhitelist(address[] indexed accounts);
    event removedFromVCWhitelist(address[] indexed accounts);

    event PurchaseCompleted(
        uint256 indexed token_amount,
        address indexed purchaser,
        uint256 indexed stable_coin_amount,
        uint256 timestamp,
        string purchase_type
    );

    event TokensRedeemed(
        uint256 indexed token_amount,
        address indexed purchaser,
        uint256 timestamp,
        string purchase_type
    );

    modifier raiseIncomplete() {
        require(!isRaiseComplete, "Raise is now complete");
        _;
    }

    modifier raiseComplete() {
        require(isRaiseComplete, "Raise not yet marked complete");
        _;
    }

    modifier onlyPurchased() {
        require(
            purchases[msg.sender].token_amount != 0,
            "You have not purchased the tokens"
        );
        _;
    }

    constructor(address _sale_token_address, address _stable_coin_address) {
        sale_token = ERC20(_sale_token_address);
        stable_coin = ERC20(_stable_coin_address);
    }

    function whitelistInfluencer(address[] memory _influencer_addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _influencer_addresses.length; i++) {
            require(influencer_whitelist[_influencer_addresses[i]] != true);
            influencer_whitelist[_influencer_addresses[i]] = true;
        }
        emit addedToInfluencerWhitelist(_influencer_addresses);
    }

    function whitelistIndividual(address[] memory _individual_addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _individual_addresses.length; i++) {
            require(individual_whitelist[_individual_addresses[i]] != true);
            individual_whitelist[_individual_addresses[i]] = true;
        }
        emit addedToIndividualWhitelist(_individual_addresses);
    }

    function whitelistVC(address[] memory _vc_addresses) external onlyOwner {
        for (uint256 i = 0; i < _vc_addresses.length; i++) {
            require(vc_whitelist[_vc_addresses[i]] != true);
            vc_whitelist[_vc_addresses[i]] = true;
        }
        emit addedToVCWhitelist(_vc_addresses);
    }

    function removeWhitelistInfluencer(address[] memory _influencer_addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _influencer_addresses.length; i++) {
            require(influencer_whitelist[_influencer_addresses[i]] != false);
            influencer_whitelist[_influencer_addresses[i]] = false;
        }
        emit removedFromInfluencerWhitelist(_influencer_addresses);
    }

    function removeWhitelistIndividual(address[] memory _individual_addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _individual_addresses.length; i++) {
            require(individual_whitelist[_individual_addresses[i]] != false);
            individual_whitelist[_individual_addresses[i]] = false;
        }
        emit removedFromIndividualWhitelist(_individual_addresses);
    }

    function removeWhitelistVC(address[] memory _vc_addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _vc_addresses.length; i++) {
            require(vc_whitelist[_vc_addresses[i]] != false);
            vc_whitelist[_vc_addresses[i]] = false;
        }
        emit removedFromVCWhitelist(_vc_addresses);
    }

    function purchaseInfluencer() external raiseIncomplete {
        require(
            influencer_whitelist[msg.sender],
            "You are not whitelisted as an influencer"
        );
        require(
            influencer_purchase_count < max_influencer,
            "Influencer allocations are exhausted"
        );
        require(
            influencer_purchased[msg.sender] == 0,
            "You have already claimed your allocation"
        );
        uint256 stable_coin_amount = influencer_tokens
        .mul(exchange_rate_cents)
        .div(100) // cents to USD
        .mul(
            1e6 // USDT or USDC both have 6 decimals
        );

        require(
            stable_coin.transferFrom(
                msg.sender,
                address(this),
                stable_coin_amount
            ),
            "Purchase failed"
        );

        raised_funds.add(stable_coin_amount);
        influencer_purchase_count = influencer_purchase_count.add(1);
        influencer_purchased[msg.sender] = influencer_tokens;

        Purchase memory purchase = Purchase(
            influencer_tokens,
            msg.sender,
            stable_coin_amount,
            block.timestamp,
            "Influencer",
            false
        );
        purchases[msg.sender] = purchase;

        emit PurchaseCompleted(
            influencer_tokens,
            msg.sender,
            stable_coin_amount,
            block.timestamp,
            "Influencer"
        );
    }

    function purchaseIndividual() external raiseIncomplete {
        require(
            individual_whitelist[msg.sender],
            "You are not whitelisted as an individual"
        );
        require(
            individual_purchase_count < max_individual,
            "Individual allocations are exhausted"
        );
        require(
            individual_purchased[msg.sender] == 0,
            "You have already claimed your allocation"
        );
        uint256 stable_coin_amount = individual_tokens
        .mul(exchange_rate_cents)
        .div(100) // cents to USD
        .mul(
            1e6 // USDT or USDC both have 6 decimals
        );

        require(
            stable_coin.transferFrom(
                msg.sender,
                address(this),
                stable_coin_amount
            ),
            "Purchase failed"
        );

        raised_funds.add(stable_coin_amount);
        individual_purchase_count = individual_purchase_count.add(1);
        individual_purchased[msg.sender] = individual_tokens;

        Purchase memory purchase = Purchase(
            individual_tokens,
            msg.sender,
            stable_coin_amount,
            block.timestamp,
            "Individual",
            false
        );
        purchases[msg.sender] = purchase;

        emit PurchaseCompleted(
            individual_tokens,
            msg.sender,
            stable_coin_amount,
            block.timestamp,
            "Individual"
        );
    }

    function purchaseVc() external raiseIncomplete {
        require(vc_whitelist[msg.sender], "You are not whitelisted as an vc");
        require(vc_purchase_count < max_vc, "Vc allocations are exhausted");
        require(
            vc_purchased[msg.sender] == 0,
            "You have already claimed your allocation"
        );
        uint256 stable_coin_amount = vc_tokens
        .mul(exchange_rate_cents)
        .div(100) // cents to USD
        .mul(
            1e6 // USDT or USDC both have 6 decimals
        );

        require(
            stable_coin.transferFrom(
                msg.sender,
                address(this),
                stable_coin_amount
            ),
            "Purchase failed"
        );

        raised_funds.add(stable_coin_amount);
        vc_purchase_count = vc_purchase_count.add(1);
        vc_purchased[msg.sender] = vc_tokens;

        Purchase memory purchase = Purchase(
            vc_tokens,
            msg.sender,
            stable_coin_amount,
            block.timestamp,
            "VC",
            false
        );
        purchases[msg.sender] = purchase;

        emit PurchaseCompleted(
            vc_tokens,
            msg.sender,
            stable_coin_amount,
            block.timestamp,
            "VC"
        );
    }

    function redeemTokens() external onlyPurchased raiseComplete nonReentrant {
        Purchase memory purchase = purchases[msg.sender];
        require(!purchase.withdrawn, "Address has already redeemed tokens");
        purchase.withdrawn = true;
        purchases[msg.sender] = purchase;
        require(
            sale_token.transfer(
                purchase.purchaser,
                purchase.token_amount.mul(1e18).mul(TGE_unlock).div(100) // convert to percent
            ),
            "Redeem transfer failed"
        );
        emit TokensRedeemed(
            purchase.token_amount,
            purchase.purchaser,
            block.timestamp,
            purchase.purchase_type
        );
    }

    function markRaiseComplete() external onlyOwner {
        isRaiseComplete = true;
    }

    function markRaiseInComplete() external onlyOwner {
        isRaiseComplete = false;
    }

    function withdrawFunds() external onlyOwner {
        // Withdraw all raised funds to owner
        stable_coin.transfer(msg.sender, stable_coin.balanceOf(address(this)));
    }

    function withdrawUnsoldTokens() external onlyOwner raiseComplete {
        // Withdraw unsold $WHIRL
        uint256 unsoldTokens = sale_token.balanceOf(address(this));
        if (unsoldTokens > 0) {
            require(
                sale_token.transfer(msg.sender, unsoldTokens),
                "Token withdraw failed"
            );
        }
    }

    function removeOtherERC20Tokens(address _tokenAddress, address _to)
        external
        onlyOwner
    {
        require(
            _tokenAddress != address(sale_token),
            "Token Address has to be diff than $WHIRL token"
        );
        ERC20 erc20Token = ERC20(_tokenAddress);
        require(
            erc20Token.transfer(_to, erc20Token.balanceOf(address(this))),
            "ERC20 Token transfer failed"
        );
    }
}
