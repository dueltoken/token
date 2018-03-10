var HDWalletProvider = require("truffle-hdwallet-provider");
var infura_apikey =  process.env.INFURA_APIKEY;
var mnemonic = process.env.WALLET_WORDS;

module.exports = {
  networks: {
    development: {
          host: "localhost",
          port: 7545,
          network_id: "*"
    },
    kovan: {
          provider: new HDWalletProvider(mnemonic, "https://kovan.infura.io/"+infura_apikey),
          network_id: 3,
          gas:   6599987,
          gasPrice: 1000000000
    }
}
};
