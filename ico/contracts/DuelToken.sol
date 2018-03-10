pragma solidity ^0.4.19;

import "./lib/SafeMath.sol";
import "./lib/TradableToken.sol";


contract DuelToken is TradableToken {

    string public name = "duel token";
    string public symbol = "DUEL";
    uint public constant decimals = 18;

    uint256 public constant INITIAL_SUPPLY = 500000000*(10**18);

    function DuelToken() public {
        totalSupply = INITIAL_SUPPLY;
        balances[msg.sender] = INITIAL_SUPPLY;
        Transfer(0x0, msg.sender, INITIAL_SUPPLY);
    }
}