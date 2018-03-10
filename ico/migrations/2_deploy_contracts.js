const DuelTokenCrowdsale = artifacts.require("./contracts/DuelTokenCrowdsale.sol");

module.exports = function(deployer, network, accounts) {
    deployer.deploy(DimitriCoinCrowdsale);
};