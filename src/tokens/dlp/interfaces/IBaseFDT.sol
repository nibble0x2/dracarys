// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.6.0 <0.9.0;

interface IBaseFDT {
	/**
        @dev    Returns the total amount of funds a given address is able to withdraw currently.
        @param  owner Address of FDT holder.
        @return A uint256 representing the available funds for a given account.
    */
	function withdrawableFundsOf_DLP(address owner) external view returns (uint256);

	function withdrawableFundsOf_VDRCY(address owner) external view returns (uint256);

	/**
        @dev Withdraws all available funds for a FDT holder.
    */
	function withdrawFunds_DLP() external;

	function withdrawFunds_VDRCY() external;

	function withdrawFunds() external;

	/**
        @dev   This event emits when new funds are distributed.
        @param by               The address of the sender that distributed funds.
        @param fundsDistributed_DLP The amount of funds received for distribution.
    */
	event FundsDistributed_DLP(address indexed by, uint256 fundsDistributed_DLP);

	event FundsDistributed_VDRCY(address indexed by, uint256 fundsDistributed_VDRCY);

	/**
        @dev   This event emits when distributed funds are withdrawn by a token holder.
        @param by             The address of the receiver of funds.
        @param fundsWithdrawn_DLP The amount of funds that were withdrawn.
        @param totalWithdrawn_DLP The total amount of funds that were withdrawn.
    */
	event FundsWithdrawn_DLP(
		address indexed by,
		uint256 fundsWithdrawn_DLP,
		uint256 totalWithdrawn_DLP
	);

	event FundsWithdrawn_VDRCY(
		address indexed by,
		uint256 fundsWithdrawn_VDRCY,
		uint256 totalWithdrawn_VDRCY
	);
}
