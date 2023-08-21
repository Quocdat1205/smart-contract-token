// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.1;

import "./vnst.proxy.sol";

contract VNSTProtocol is VNSTProxy {
    function version() external pure returns (string memory) {
        return "v1!";
    }

    /**
     * @notice Event
     */
    event EMint(
        address indexed address_mint,
        uint256 amount_in,
        uint256 amount_out,
        uint256 created_at
    );
    event ERedeem(
        address indexed address_withdraw,
        uint256 amount_in,
        uint256 amount_out,
        uint256 created_at
    );

    function reBootPool(
        uint256 _market_price,
        uint256 _usdt_pool,
        uint256 _redeem_covered_amount,
        uint256 _mint_covered_amount
    ) external {
        require(hasRole(MODERATOR_ROLE, msg.sender), "Caller doesn't have permission");
        market_price = _market_price;
        usdt_pool = _usdt_pool;
        vnst_pool = usdt_pool * (market_price / _rate_decimal);
        redeem_covered_amount = _redeem_covered_amount;
        mint_covered_amount = _mint_covered_amount;
        redeem_covered_price = market_price + 200000000;
        mint_covered_price = market_price - 100000000;
        k = usdt_pool * vnst_pool;
    }

    function _calculateVMM(uint256 x, uint256 y, uint256 Dx) private pure returns (uint256) {
        uint256 Dy = (y * Dx) / (x + Dx);
        return Dy;
    }

    function _getAmountVNSTSupport(uint256 amount_usdt_in) private view returns (uint256) {
        uint256 amount_vnst_support_out = (amount_usdt_in * mint_covered_price) / _rate_decimal;
        return amount_vnst_support_out;
    }

    function _getAmountUSDTSupport(uint256 amount_vnst_in) private view returns (uint256) {
        uint256 amount_usdt_support_out = (amount_vnst_in * _rate_decimal) / redeem_covered_price;
        return amount_usdt_support_out;
    }

    function _getUSDTInBeforeCovered() private view returns (uint256) {
        uint256 amount_usdt_in_before_support = Math.sqrt(
            (k * _rate_decimal) / mint_covered_price
        ) - usdt_pool;
        return amount_usdt_in_before_support;
    }

    function _getVNSTInBeforeCovered() private view returns (uint256) {
        uint256 amount_vnst_in_before_support = Math.sqrt(
            (k * redeem_covered_price) / _rate_decimal
        ) - vnst_pool;
        return amount_vnst_in_before_support;
    }

    function _updatePool(uint256 _vnst_pool, uint256 _usdt_pool) private {
        vnst_pool = _vnst_pool;
        usdt_pool = _usdt_pool;
        market_price = (vnst_pool * _rate_decimal) / usdt_pool;
    }

    /// @param amount_usdt Q-in: Input amount
    function mint(uint256 amount_usdt) external nonReentrant whenNotPaused {
        // Check balance usdt caller
        require(usdt.balanceOf(address(msg.sender)) >= amount_usdt, "USDT doesn't enough");
        require(amount_usdt >= 5 * 10 ** 18, "Min amount usdt is 5");
        require(market_price >= mint_covered_price, "Something wrong");

        // Case VMM not available
        if (market_price == mint_covered_price) {
            uint256 amount_vnst_support_out = _getAmountVNSTSupport(amount_usdt);

            // Check cover pool
            uint256 _mint_covered_amount = mint_covered_amount - amount_vnst_support_out;
            require(_mint_covered_amount > 0, "Run out of Q support bellow");

            // Update cover pool
            mint_covered_amount = _mint_covered_amount;

            // transfer usdt from caller to pool
            usdt.transferFrom(_msgSender(), address(this), amount_usdt);

            // mint token and transfer to caller
            _mint(_msgSender(), amount_vnst_support_out);

            //Event
            emit EMint(_msgSender(), amount_usdt, amount_vnst_support_out, block.timestamp);
        }
        // Case VMM available
        else if (market_price > mint_covered_price) {
            uint256 amount_usdt_in_before_support = _getUSDTInBeforeCovered();

            // Case mint don't hit cover price
            if (amount_usdt <= amount_usdt_in_before_support) {
                uint256 amount_vnst_out = _calculateVMM(usdt_pool, vnst_pool, amount_usdt);

                // update pool
                _updatePool(vnst_pool - amount_vnst_out, usdt_pool + amount_usdt);

                // transfer usdt from caller to pool
                usdt.transferFrom(_msgSender(), address(this), amount_usdt);

                // mint token and transfer to caller
                _mint(_msgSender(), amount_vnst_out);

                // Event
                emit EMint(_msgSender(), amount_usdt, amount_vnst_out, block.timestamp);
            }
            // Case mint hit cover price
            else if (amount_usdt > amount_usdt_in_before_support) {
                uint256 amount_vnst_out = _calculateVMM(
                    usdt_pool,
                    vnst_pool,
                    amount_usdt_in_before_support
                );

                uint256 amount_vnst_support_out = _getAmountVNSTSupport(
                    amount_usdt - amount_usdt_in_before_support
                );

                // Check cover pool
                uint256 _mint_covered_amount = mint_covered_amount - amount_vnst_support_out;
                require(mint_covered_amount > 0, "Run out of Q support bellow");

                // update pool and cover pool
                _updatePool(vnst_pool - amount_vnst_out, usdt_pool + amount_usdt_in_before_support);
                mint_covered_amount = _mint_covered_amount;

                // transfer usdt from caller to pool
                usdt.transferFrom(_msgSender(), address(this), amount_usdt);

                // mint token and transfer to caller
                _mint(_msgSender(), amount_vnst_out + amount_vnst_support_out);

                // Event
                emit EMint(
                    _msgSender(),
                    amount_usdt,
                    amount_vnst_out + amount_vnst_support_out,
                    block.timestamp
                );
            }
        }
    }

    /// @param amount_vnst Q-in: Input amount
    function redeem(uint256 amount_vnst) external nonReentrant whenNotPaused {
        // check balance vnst caller
        require(balanceOf(_msgSender()) >= amount_vnst, "VNST doesn't enough");
        require(amount_vnst >= 100000 * 10 ** 18, "Min amount vnst is 100000");
        require(market_price <= redeem_covered_price, "Something wrong");

        // Case VMM not available
        if (market_price == redeem_covered_price) {
            uint256 amount_usdt_support_out = _getAmountUSDTSupport(amount_vnst);

            // Check cover pool
            uint256 _redeem_covered_amount = redeem_covered_amount - amount_usdt_support_out;
            require(_redeem_covered_amount > 0, "Run out of Q support above");

            // Update covered pool and operation pool
            redeem_covered_amount = _redeem_covered_amount;
            operation_pool = operation_pool + (amount_usdt_support_out / 1000);

            // burn token
            _burn(_msgSender(), amount_vnst);

            // transfer usdt from pool to caller
            usdt.transfer(_msgSender(), amount_usdt_support_out - (amount_usdt_support_out / 1000));

            emit ERedeem(
                _msgSender(),
                amount_vnst,
                amount_usdt_support_out - (amount_usdt_support_out / 1000),
                block.timestamp
            );
        }
        // Case VMM available
        else if (market_price < redeem_covered_price) {
            uint256 amount_vnst_in_before_support = _getVNSTInBeforeCovered();

            // Case redeem don't hit cover price
            if (amount_vnst <= amount_vnst_in_before_support) {
                uint256 amount_usdt_out = _calculateVMM(vnst_pool, usdt_pool, amount_vnst);

                // update pool and operation pool
                _updatePool(vnst_pool + amount_vnst, usdt_pool - amount_usdt_out);
                operation_pool = operation_pool + (amount_usdt_out / 1000);

                // burn token
                _burn(_msgSender(), amount_vnst);

                // transfer usdt from pool to caller
                usdt.transfer(_msgSender(), amount_usdt_out - (amount_usdt_out / 1000));

                emit ERedeem(
                    _msgSender(),
                    amount_vnst,
                    amount_usdt_out - (amount_usdt_out / 1000),
                    block.timestamp
                );
            }
            // Case redeem hit cover price
            else if (amount_vnst > amount_vnst_in_before_support) {
                uint256 amount_usdt_out = _calculateVMM(
                    vnst_pool,
                    usdt_pool,
                    amount_vnst_in_before_support
                );

                uint256 amount_usdt_support_out = _getAmountUSDTSupport(
                    amount_vnst - amount_vnst_in_before_support
                );

                // Check cover pool
                uint256 _redeem_covered_amount = redeem_covered_amount - amount_usdt_support_out;
                require(_redeem_covered_amount > 0, "Run out of Q support above");

                uint256 sum_usdt_out = amount_usdt_out + amount_usdt_support_out;

                // update pool and cover pool and operation pool
                _updatePool(vnst_pool + amount_vnst_in_before_support, usdt_pool - amount_usdt_out);
                redeem_covered_amount = _redeem_covered_amount;
                operation_pool = operation_pool + (sum_usdt_out / 1000);

                // burn token
                _burn(_msgSender(), amount_vnst);

                // transfer usdt from pool to caller
                usdt.transfer(_msgSender(), sum_usdt_out - (sum_usdt_out / 1000));

                emit ERedeem(
                    _msgSender(),
                    amount_vnst,
                    sum_usdt_out - (sum_usdt_out / 1000),
                    block.timestamp
                );
            }
        }
    }
}
