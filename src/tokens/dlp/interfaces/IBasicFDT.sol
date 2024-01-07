// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IBaseFDT.sol";

interface IBasicFDT is IBaseFDT, IERC20 {
	event PointsPerShareUpdated_DLP(uint256);

	event PointsCorrectionUpdated_DLP(address indexed, int256);

	event PointsPerShareUpdated_VDRCY(uint256);

	event PointsCorrectionUpdated_VDRCY(address indexed, int256);

	function withdrawnFundsOf_DLP(address) external view returns (uint256);

	function accumulativeFundsOf_DLP(address) external view returns (uint256);

	function withdrawnFundsOf_VDRCY(address) external view returns (uint256);

	function accumulativeFundsOf_VDRCY(address) external view returns (uint256);

	function updateFundsReceived_DLP() external;

	function updateFundsReceived_VDRCY() external;
}
