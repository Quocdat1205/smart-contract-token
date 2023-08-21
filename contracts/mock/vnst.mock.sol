// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.1;

import "../vnst.upgrade.sol";

contract MockVNST is VNSTProtocol {
    function setMarketPrice(uint256 _market_price) external {
        market_price = _market_price;
    }
}
