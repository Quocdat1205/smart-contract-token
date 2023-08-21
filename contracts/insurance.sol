// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interface/iinsurance.sol";

contract Insurance is IInsurance, Ownable {
    // variable general
    address payable private admin;
    uint256 public totalInsurance;
    uint256 public quantity_nain_eligible_for_incentives;
    address public address_nain;
    bool public enable_user_nain;
    bool public enable_buy_insurance;
    IERC20 token_nain;
    IERC20 usdt;

    constructor(address _addressUSDT) {
        admin = payable(msg.sender);
        totalInsurance = 0;
        usdt = IERC20(_addressUSDT);
        quantity_nain_eligible_for_incentives = 99 * 10 ** 18;
        enable_user_nain = false;
        enable_buy_insurance = true;
    }

    mapping(uint256 => InsuranceStruct) private insurance;
    mapping(uint256 => bool) private insurance_payment;

    /*
     @event
    **/
    event EBuyInsurance(
        uint256 idInsurance,
        address buyer,
        string asset,
        uint256 margin,
        uint256 q_covered,
        uint256 p_market,
        uint256 p_claim,
        string state,
        uint256 period,
        uint256 recognition_date,
        bool isUseNain
    );
    event EUpdateStateInsurance(uint256 idInsurance);
    event EUpdateQuantityNainEligibleForIncentives(
        uint256 quantity_nain_eligible_for_incentives
    );
    event ECancelStateInsurance(uint256 idInsurnace);
    event EValidInsurance(uint256 idInsurnace);

    // Only owner has permission to perform this function
    modifier onlyContractCaller(address _caller) {
        require(
            msg.sender == _caller,
            "Only the person who is calling the contract will be executed"
        );
        _;
    }
    modifier checkAllowance(uint256 amount) {
        require(
            usdt.allowance(msg.sender, address(this)) >= amount,
            "Error allowance"
        );
        _;
    }

    function configAddressNain(
        address _address_nain
    ) external override onlyOwner {
        address_nain = _address_nain;
        token_nain = IERC20(_address_nain);
        enable_user_nain = true;
    }

    function renounceNain() external override onlyOwner {
        enable_user_nain = false;
    }

    function enableNain() external {
        enable_user_nain = true;
    }

    function updateQuantityNainEligibleForIncentives(
        uint256 _quantity
    ) external onlyOwner {
        quantity_nain_eligible_for_incentives = _quantity;
    }

    function insuranceState(
        uint256 _insuranceId
    ) external view override returns (InsuranceStruct memory) {
        return insurance[_insuranceId];
    }

    function createInsurance(
        address _buyer,
        string memory _asset,
        uint256 _margin,
        uint256 _q_covered,
        uint256 _p_market,
        uint256 _p_claim,
        uint256 _period,
        bool useNain
    )
        external
        payable
        override
        onlyContractCaller(_buyer)
        checkAllowance(_margin)
        returns (InsuranceStruct memory)
    {
        require(
            _period >= 1 && _period <= 15,
            "The time must be within the specified range 1 - 15"
        );
        require(
            usdt.balanceOf(address(msg.sender)) >= _margin,
            "USDT does't enough"
        );
        require(!enable_buy_insurance, "Feature buy insurance is disabled");
        require(useNain && !enable_user_nain, "Feature use Nain is disabled");

        if (useNain && enable_user_nain) {
            require(
                token_nain.balanceOf(address(msg.sender)) >=
                    quantity_nain_eligible_for_incentives,
                "NAIN does't enough, please check again!"
            );

            // transfer nain
            token_nain.transferFrom(
                msg.sender,
                admin,
                quantity_nain_eligible_for_incentives
            );
        }

        usdt.transferFrom(msg.sender, admin, _margin);

        InsuranceStruct memory newInsurance = InsuranceStruct(
            totalInsurance + 1,
            _buyer,
            _asset,
            _margin,
            _q_covered,
            _p_market,
            _p_claim,
            "Available",
            _period,
            block.timestamp,
            block.timestamp,
            useNain
        );
        insurance[totalInsurance + 1] = newInsurance;

        emit EBuyInsurance(
            totalInsurance + 1,
            _buyer,
            _asset,
            _margin,
            _q_covered,
            _p_market,
            _p_claim,
            "Available",
            _period,
            0,
            useNain
        );

        totalInsurance++;

        return newInsurance;
    }

    function cancelInsurance(
        uint256 _idInsurance
    ) external override onlyOwner returns (string memory) {
        require(
            compareString(insurance[_idInsurance].state, "Available"),
            "State cannot be updated"
        );
        if (!insurance_payment[_idInsurance]) {
            revert("State cannot be updated");
        }
        insurance_payment[_idInsurance] = true;
        insurance[_idInsurance].state = "Canceled";
        insurance[_idInsurance].recognition_date = block.timestamp;

        usdt.transferFrom(
            msg.sender,
            insurance[_idInsurance].buyer,
            insurance[_idInsurance].margin
        );

        emit ECancelStateInsurance(_idInsurance);

        return "Update success";
    }

    function invalidInsurance(
        uint256 _idInsurance
    ) external override onlyOwner returns (string memory) {
        require(
            compareString(insurance[_idInsurance].state, "Available"),
            "Invalid error"
        );
        if (!insurance_payment[_idInsurance]) {
            revert("Invalid error");
        }
        insurance_payment[_idInsurance] = true;
        insurance[_idInsurance].state = "Invalid";
        insurance[_idInsurance].recognition_date = block.timestamp;

        usdt.transferFrom(
            msg.sender,
            insurance[_idInsurance].buyer,
            insurance[_idInsurance].margin
        );

        emit EValidInsurance(_idInsurance);

        return "Update success";
    }

    function updateStateInsurance(
        uint256 _idInsurance,
        string memory _state
    ) external override onlyOwner returns (string memory) {
        // validate state
        require(
            compareString(_state, "Claim_waiting") ||
                compareString(_state, "Claimed") ||
                compareString(_state, "Refunded") ||
                compareString(_state, "Liquidated") ||
                compareString(_state, "Expired"),
            "State does not exist"
        );

        if (
            compareString(insurance[_idInsurance].state, "Claimed") ||
            compareString(insurance[_idInsurance].state, "Refunded") ||
            compareString(insurance[_idInsurance].state, "Liquidated") ||
            compareString(insurance[_idInsurance].state, "Expired") ||
            compareString(insurance[_idInsurance].state, "Canceled")
        ) {
            revert("State has been update");
        }
        insurance[_idInsurance].state = _state;
        insurance[_idInsurance].recognition_date = block.timestamp;

        emit EUpdateStateInsurance(_idInsurance);

        return "success";
    }

    function configInsurance(bool _mode) external override onlyOwner {
        enable_buy_insurance = _mode;
    }

    /*
     @helper
    **/
    function compareString(
        string memory a,
        string memory b
    ) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
