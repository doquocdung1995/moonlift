// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

abstract contract PairsHolder {
    mapping(address => bool) public pairs;

    function _addPairToTrack(address pair) internal {
        require(!isPair(pair), "Already tracking");
        pairs[pair] = true;
    }

    function isPair(address account) public view returns (bool) {
        return pairs[account];
    }
}
