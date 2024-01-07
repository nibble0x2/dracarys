// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./MintableBaseToken.sol";

contract DLP is MintableBaseToken {
	constructor(
		address _vaultRegistry,
		address _timelock,
		address _vdrcyAddress
	) MintableBaseToken("DRCY LP", "DLP", _vdrcyAddress, _vaultRegistry, _timelock) {}

	function id() external pure returns (string memory _name) {
		return "DLP";
	}
}
