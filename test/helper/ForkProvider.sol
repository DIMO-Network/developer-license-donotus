// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/**
 */
contract ForkProvider {

    string public _url;

    constructor() {

        //_url = 'https://polygon-mainnet.g.alchemy.com/v2/NlPy1jSLyP-tUCHAuilxrsfaLcFaxSTm';
        _url = 'https://polygon-mainnet.infura.io/v3/89d890fd291a4096a41aea9b3122eb28';
    }

}
