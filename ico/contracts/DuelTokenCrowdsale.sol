pragma solidity ^0.4.18;

import "./lib/Ownable.sol";
import "./lib/SafeMath.sol";
import "./lib/AddressWhitelist.sol";
import "./DuelToken.sol";


contract DuelTokenCrowdsale is Ownable, AddressWhitelist {
    using SafeMath for uint256;

    enum IcoPhase {PreSale, Phase1, Phase2, Closed, Ended}

    DuelToken public duelToken;

    uint256 public totalTokensToSell = duel(300000000);
    uint256 public tokensRemaining = totalTokensToSell;
    address public founderWallet = 0; //TODO: add address
    address public minablePoolWallet = 0; //TODO: add address
    address public partnerWallet = 0; //TODO: add address
    address public bountyWallet = 0; //TODO: add address
    address public frozenWallet = 0; //TODO: add address
    uint256 public baseTokensPerEth = duel(12000);

    uint256 public amountRaisedInWei = 0;
    uint256 public softCapInWei = 0.5 ether;

    uint256 public icoStartTimestamp;
    bool    public isCrowdSaleSetup = false;



    uint256 public maxGasPrice = 50000000000; //50 gwei

    event Buy(address indexed _sender, uint256 _eth, uint256 _duel);
    event Refund(address indexed _refunder, uint256 _value);

    mapping(address => uint256) private contributedAmount;

    function() external payable {
        require(tx.gasprice <= maxGasPrice);
        require(msg.data.length == 0);
        buyDuelTokens();
    }

    function refund() external {
        require(!softCapReached());
        require(icoEnded());
        require(contributedAmount[msg.sender] > 0);

        uint256 ethRefund = contributedAmount[msg.sender];
        contributedAmount[msg.sender] = 0;

        msg.sender.transfer(ethRefund);
        Refund(msg.sender, ethRefund);
    }

    function setupCrowdsale(uint256 _fundingStartTime) external onlyOwner {
        require(!isCrowdSaleSetup);
        duelToken = new DuelToken();
        icoStartTimestamp = _fundingStartTime;
        isCrowdSaleSetup = true;
    }

    function distributeTokensToLockedAccounts() external onlyOwner {
        require(icoEnded() && softCapReached());
        founderWallet.transfer(this.balance);

        duelToken.transfer(founderWallet, getSalePercentageOf(duel(75000000)));
        duelToken.transfer(bountyWallet, getSalePercentageOf(duel(25000000)));
        duelToken.transfer(minablePoolWallet, getSalePercentageOf(duel(50000000)));
        duelToken.transfer(partnerWallet, getSalePercentageOf(duel(50000000)));
        duelToken.transfer(frozenWallet, duelToken.balanceOf(this));
    }

    function updateMaxGasPrice(uint256 _newGasPrice) public onlyOwner {
        require(_newGasPrice != 0);
        maxGasPrice = _newGasPrice;
    }

    function buyDuelTokens() public payable {
        require(!(msg.value == 0));
        require(isCrowdSaleSetup);
        require(getCurrentPhase() != IcoPhase.Closed);
        require(tokensRemaining > 0);

        if (getCurrentPhase() == IcoPhase.PreSale) {
            assert(isWhitelisted(msg.sender));
        }

        uint256 amountOfTokensToSend = 0;
        uint256 contributionInWei = msg.value;
        uint256 weiRaised = 0;
        uint256 refundInWei = 0;


        uint256 amountOfTokens = calculateAmountOfBaseTokensForWeiValue(msg.value);

        if (amountOfTokens > tokensRemaining) {
            uint256 priceOfRemainingTokens = calculatePriceForTokensInWei(tokensRemaining);
            amountOfTokensToSend = tokensRemaining;
            refundInWei = contributionInWei.sub(priceOfRemainingTokens);
            weiRaised = contributionInWei.sub(refundInWei);
        } else {
            amountOfTokensToSend = amountOfTokens;
            weiRaised = contributionInWei;
        }

        amountRaisedInWei = amountRaisedInWei.add(weiRaised);
        tokensRemaining = tokensRemaining.sub(amountOfTokensToSend);

        contributedAmount[msg.sender] = contributedAmount[msg.sender].add(weiRaised);
        duelToken.transfer(msg.sender, amountOfTokensToSend);
        Buy(msg.sender, weiRaised, amountOfTokensToSend);
        if (refundInWei > 0) {
            msg.sender.transfer(refundInWei);
        }
    }

    function checkGoalReached() public view returns (string response) {
        if (!isCrowdSaleSetup) {
            return "Crowdsale deployed but not set-up";
        } else if (icoNotStarted() && isCrowdSaleSetup) {
            return "Crowdsale is setup";
        } else if (icoOngoing() && !softCapReached()) {
            return "ICO in progress; Softcap not reached yet";
        } else if (icoOngoing() && softCapReached() && tokensRemaining > 0) {
            return "ICO in progress; Softcap reached";
        } else if (icoEnded() && !softCapReached()) {
            return "ICO ended; Softcap not reached; Everyone is refunded";
        } else if (icoEnded() && softCapReached() && tokensRemaining > 0) {
            return "ICO ended;  Softcap reached";
        } else if (softCapReached() && (tokensRemaining == 0)) {
            return "ICO ended; All tokens sold!";
        }
    }

    function getBonusPrice() public view returns (uint256) {
        IcoPhase currentPhase = getCurrentPhase();
        if (currentPhase == IcoPhase.PreSale) {
            return duel(8000);
        } else if (currentPhase == IcoPhase.Phase1) {
            return duel(3000);
        } else {
            return 0;
        }
    }

    function getCurrentPhase() public view returns (IcoPhase) {
        uint256 presaleDuration = 1 days;
        uint256 phase1Duration = 6 days;
        uint256 phase2Duration = 3 weeks;

        uint256 phase1StartTime = icoStartTimestamp + presaleDuration;
        uint256 phase2StartTime = phase1StartTime + phase1Duration;
        if (tokensRemaining == 0) {
            return IcoPhase.Ended;
        } else if (isInTimeFrame(icoStartTimestamp, presaleDuration)) {
            return IcoPhase.PreSale;
        } else if (isInTimeFrame(phase1StartTime, phase1Duration)) {
            return IcoPhase.Phase1;
        } else if (isInTimeFrame(phase2StartTime, phase2Duration)) {
            return IcoPhase.Phase2;
        } else if (now > phase2StartTime + phase2Duration) {
            return IcoPhase.Ended;
        } else {
            return IcoPhase.Closed;
        }
    }

    function duel(uint256 amount) public pure returns (uint256) {
        return amount.mul(10 ** 18);
    }

    function makeTokensTradable() public onlyOwner {
        require(icoEnded() && softCapReached());
        duelToken.enableTrading();
    }

    function calculateAmountOfBaseTokensForWeiValue(uint256 ethPayedInWei) private view returns (uint256) {
        uint256 tokensPerEthWithBonus = baseTokensPerEth.add(getBonusPrice());
        return ethPayedInWei.mul(tokensPerEthWithBonus).div(10**18);
    }

    function calculatePriceForTokensInWei(uint256 tokenAmount) private view returns (uint256) {
        uint256 tokensPerWeiWithBonus = baseTokensPerEth.add(getBonusPrice()).div(10**18);
        return tokenAmount.div(tokensPerWeiWithBonus);
    }

    function isInTimeFrame(uint256 time1, uint256 range) private view returns (bool) {
        return (now >= time1 && now <= time1.add(range));
    }

    function softCapReached() private view returns (bool) {
        return amountRaisedInWei >= softCapInWei;
    }

    function icoNotStarted() private view returns (bool) {
        return getCurrentPhase() == IcoPhase.Closed;
    }

    function icoEnded() private view returns (bool) {
        return getCurrentPhase() == IcoPhase.Ended;
    }

    function icoOngoing() private view returns (bool) {
        return getCurrentPhase() != IcoPhase.Ended && getCurrentPhase() != IcoPhase.Closed;
    }

    function getSalePercentageOf(uint256 amountOfTokens) private view returns (uint256) {
        uint256 tokensSold = totalTokensToSell.sub(tokensRemaining);
        uint256 percentage = tokensSold.mul(10000).div(totalTokensToSell);
        return amountOfTokens.mul(percentage).div(10000);
    }
}