// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IInsurance {
    struct InsuranceStruct {
        uint256 idInsurance;
        address buyer;
        string asset;
        uint256 margin;
        uint256 q_covered;
        uint256 p_market;
        uint256 p_claim;
        string state;
        uint256 period;
        uint256 recognition_date;
        uint256 expired;
        bool isUseNain;
    }

    function configAddressNain(address _address_nain) external;

    function renounceNain() external;

    function insuranceState(
        uint256 _insuranceId
    ) external view returns (InsuranceStruct memory);

    function createInsurance(
        address _buyer,
        string memory _asset,
        uint256 _margin,
        uint256 _q_covered,
        uint256 _p_market,
        uint256 _p_claim,
        uint256 _period,
        bool _isUseNain
    ) external payable returns (InsuranceStruct memory);

    function cancelInsurance(
        uint256 _idInsurance
    ) external returns (string memory);

    function invalidInsurance(
        uint256 _idInsurance
    ) external returns (string memory);

    function updateStateInsurance(
        uint256 _idInsurance,
        string memory _state
    ) external returns (string memory);

    function configInsurance(bool _mode) external;
}
