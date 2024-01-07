// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "openzeppelin-contracts/contracts/access/AccessControlEnumerable.sol";

contract Access is AccessControlEnumerable {
	constructor(address _gov) {
		_grantRole(DEFAULT_ADMIN_ROLE, _gov);
	}

	modifier onlyGovernance() {
		require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "ACCESS: Not governance");
		_;
	}
}
