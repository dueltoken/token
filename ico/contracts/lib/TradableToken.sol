pragma solidity ^0.4.18;

import "./PausableToken.sol";


contract TradableToken is PausableToken {

    bool public tradeStarted;

    function TradableToken() public {
        tradeStarted = false;
    }

    function transfer(address _to, uint256 _value) public isTradable returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public isTradable returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    function enableTrading() public onlyOwner {
        tradeStarted = true;
    }

    modifier isTradable() {
        require(tradeStarted || msg.sender == owner);
        _;
    }

}
