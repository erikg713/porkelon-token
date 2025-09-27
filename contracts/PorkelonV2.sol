// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Porkelon.sol";

contract PorkelonV2 is Porkelon {
    function version() public pure returns (string memory) {
        return "V2";
    }
}
