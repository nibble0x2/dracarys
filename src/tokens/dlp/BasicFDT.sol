// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IBaseFDT.sol";
import "./math/SafeMath.sol";
import "./math/SignedSafeMath.sol";
import "./math/SafeMathUint.sol";
import "./math/SafeMathInt.sol";

/// @title BasicFDT implements base level FDT functionality for accounting for revenues.
abstract contract BasicFDT is IBaseFDT, ERC20 {
	using SafeMath for uint256;
	using SafeMathUint for uint256;
	using SignedSafeMath for int256;
	using SafeMathInt for int256;

	uint256 internal constant pointsMultiplier = 2 ** 128;

	// storage for DLP token rewards
	uint256 internal pointsPerShare_DLP;
	mapping(address => int256) internal pointsCorrection_DLP;
	mapping(address => uint256) internal withdrawnFunds_DLP;

	// storage for VDRCY token rewards
	uint256 internal pointsPerShare_VDRCY;
	mapping(address => int256) internal pointsCorrection_VDRCY;
	mapping(address => uint256) internal withdrawnFunds_VDRCY;

	// events DLP token rewards
	event PointsPerShareUpdated_DLP(uint256 pointsPerShare_DLP);
	event PointsCorrectionUpdated_DLP(address indexed account, int256 pointsCorrection_DLP);

	// events VDRCY token rewards
	event PointsPerShareUpdated_VDRCY(uint256 pointsPerShare_VDRCY);
	event PointsCorrectionUpdated_VDRCY(address indexed account, int256 pointsCorrection_VDRCY);

	constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

	// ADDED FUNCTION BY GHOST

	/**
	 * The DLP on this contract (so that is DLP that has to be disbtributed as rewards, doesn't belong the the DLP that can claim this same DLP). To prevent the dust accumulation of DLP on this contract, we should deduct the balance of DLP on this contract from totalSupply, otherwise the pointsPerShare_DLP will make pointsPerShare_DLP lower as it should be
	 */
	function correctedTotalSupply() public view returns (uint256) {
		return (totalSupply() - balanceOf(address(this)));
	}

	/**
        @dev Distributes funds to token holders.
        @dev It reverts if the total supply of tokens is 0.
        @dev It emits a `FundsDistributed` event if the amount of received funds is greater than 0.
        @dev It emits a `PointsPerShareUpdated` event if the amount of received funds is greater than 0.
             About undistributed funds:
                In each distribution, there is a small amount of funds which do not get distributed,
                   which is `(value  pointsMultiplier) % totalSupply()`.
                With a well-chosen `pointsMultiplier`, the amount funds that are not getting distributed
                   in a distribution can be less than 1 (base unit).
                We can actually keep track of the undistributed funds in a distribution
                   and try to distribute it in the next distribution.
    */
	function _distributeFunds_DLP(uint256 value) internal {
		require(totalSupply() > 0, "FDT:ZERO_SUPPLY");

		if (value == 0) return;

		uint256 correctedTotalSupply_ = correctedTotalSupply();

		pointsPerShare_DLP = pointsPerShare_DLP.add(
			value.mul(pointsMultiplier) / correctedTotalSupply_
		);
		emit FundsDistributed_DLP(msg.sender, value);
		emit PointsPerShareUpdated_DLP(pointsPerShare_DLP);
	}

	function _distributeFunds_VDRCY(uint256 value) internal {
		require(totalSupply() > 0, "FDT:ZERO_SUPPLY");

		if (value == 0) return;

		uint256 correctedTotalSupply_ = correctedTotalSupply();

		pointsPerShare_VDRCY = pointsPerShare_VDRCY.add(
			value.mul(pointsMultiplier) / correctedTotalSupply_
		);
		emit FundsDistributed_VDRCY(msg.sender, value);
		emit PointsPerShareUpdated_VDRCY(pointsPerShare_VDRCY);
	}

	/**
        @dev    Prepares the withdrawal of funds.
        @dev    It emits a `FundsWithdrawn_DLP` event if the amount of withdrawn funds is greater than 0.
        @return withdrawableDividend_DLP The amount of dividend funds that can be withdrawn.
    */
	function _prepareWithdraw_DLP() internal returns (uint256 withdrawableDividend_DLP) {
		withdrawableDividend_DLP = withdrawableFundsOf_DLP(msg.sender);
		uint256 _withdrawnFunds_DLP = withdrawnFunds_DLP[msg.sender].add(
			withdrawableDividend_DLP
		);
		withdrawnFunds_DLP[msg.sender] = _withdrawnFunds_DLP;
		emit FundsWithdrawn_DLP(msg.sender, withdrawableDividend_DLP, _withdrawnFunds_DLP);
	}

	function _prepareWithdraw_VDRCY() internal returns (uint256 withdrawableDividend_VDRCY) {
		withdrawableDividend_VDRCY = withdrawableFundsOf_VDRCY(msg.sender);
		uint256 _withdrawnFunds_VDRCY = withdrawnFunds_VDRCY[msg.sender].add(
			withdrawableDividend_VDRCY
		);
		withdrawnFunds_VDRCY[msg.sender] = _withdrawnFunds_VDRCY;
		emit FundsWithdrawn_VDRCY(
			msg.sender,
			withdrawableDividend_VDRCY,
			_withdrawnFunds_VDRCY
		);
	}

	/**
        @dev    Returns the amount of funds that an account can withdraw.
        @param  _owner The address of a token holder.
        @return The amount funds that `_owner` can withdraw.
    */
	function withdrawableFundsOf_DLP(address _owner) public view returns (uint256) {
		return accumulativeFundsOf_DLP(_owner).sub(withdrawnFunds_DLP[_owner]);
	}

	function withdrawableFundsOf_VDRCY(address _owner) public view returns (uint256) {
		return accumulativeFundsOf_VDRCY(_owner).sub(withdrawnFunds_VDRCY[_owner]);
	}

	/**
        @dev    Returns the amount of funds that an account has withdrawn.
        @param  _owner The address of a token holder.
        @return The amount of funds that `_owner` has withdrawn.
    */
	function withdrawnFundsOf_DLP(address _owner) external view returns (uint256) {
		return withdrawnFunds_DLP[_owner];
	}

	function withdrawnFundsOf_VDRCY(address _owner) external view returns (uint256) {
		return withdrawnFunds_VDRCY[_owner];
	}

	/**
        @dev    Returns the amount of funds that an account has earned in total.
        @dev    accumulativeFundsOf_DLP(_owner) = withdrawableFundsOf_DLP(_owner) + withdrawnFundsOf_DLP(_owner)
                                         = (pointsPerShare_DLP * balanceOf(_owner) + pointsCorrection_DLP[_owner]) / pointsMultiplier
        @param  _owner The address of a token holder.
        @return The amount of funds that `_owner` has earned in total.
    */
	function accumulativeFundsOf_DLP(address _owner) public view returns (uint256) {
		return
			pointsPerShare_DLP
				.mul(balanceOf(_owner))
				.toInt256Safe()
				.add(pointsCorrection_DLP[_owner])
				.toUint256Safe() / pointsMultiplier;
	}

	function accumulativeFundsOf_VDRCY(address _owner) public view returns (uint256) {
		return
			pointsPerShare_VDRCY
				.mul(balanceOf(_owner))
				.toInt256Safe()
				.add(pointsCorrection_VDRCY[_owner])
				.toUint256Safe() / pointsMultiplier;
	}

	/**
        @dev   Transfers tokens from one account to another. Updates pointsCorrection_DLP to keep funds unchanged.
        @dev   It emits two `PointsCorrectionUpdated` events, one for the sender and one for the receiver.
        @param from  The address to transfer from.
        @param to    The address to transfer to.
        @param value The amount to be transferred.
    */
	function _transfer(address from, address to, uint256 value) internal virtual override {
		super._transfer(from, to, value);

		// storage for DLP token rewards
		int256 _magCorrection_DLP = pointsPerShare_DLP.mul(value).toInt256Safe();
		int256 pointsCorrectionFrom_DLP = pointsCorrection_DLP[from].add(
			_magCorrection_DLP
		);
		pointsCorrection_DLP[from] = pointsCorrectionFrom_DLP;
		int256 pointsCorrectionTo_DLP = pointsCorrection_DLP[to].sub(_magCorrection_DLP);
		pointsCorrection_DLP[to] = pointsCorrectionTo_DLP;

		// storage for VDRCY token rewards
		int256 _magCorrection_VDRCY = pointsPerShare_VDRCY.mul(value).toInt256Safe();
		int256 pointsCorrectionFrom_VDRCY = pointsCorrection_VDRCY[from].add(
			_magCorrection_VDRCY
		);
		pointsCorrection_VDRCY[from] = pointsCorrectionFrom_VDRCY;
		int256 pointsCorrectionTo_VDRCY = pointsCorrection_VDRCY[to].sub(
			_magCorrection_VDRCY
		);
		pointsCorrection_VDRCY[to] = pointsCorrectionTo_VDRCY;

		emit PointsCorrectionUpdated_DLP(from, pointsCorrectionFrom_DLP);
		emit PointsCorrectionUpdated_DLP(to, pointsCorrectionTo_DLP);

		emit PointsCorrectionUpdated_VDRCY(from, pointsCorrectionFrom_VDRCY);
		emit PointsCorrectionUpdated_VDRCY(to, pointsCorrectionTo_VDRCY);
	}

	/**
        @dev   Mints tokens to an account. Updates pointsCorrection_DLP to keep funds unchanged.
        @param account The account that will receive the created tokens.
        @param value   The amount that will be created.
    */
	function _mint(address account, uint256 value) internal virtual override {
		super._mint(account, value);

		int256 _pointsCorrection_DLP = pointsCorrection_DLP[account].sub(
			(pointsPerShare_DLP.mul(value)).toInt256Safe()
		);

		pointsCorrection_DLP[account] = _pointsCorrection_DLP;

		int256 _pointsCorrection_VDRCY = pointsCorrection_VDRCY[account].sub(
			(pointsPerShare_VDRCY.mul(value)).toInt256Safe()
		);

		pointsCorrection_VDRCY[account] = _pointsCorrection_VDRCY;

		emit PointsCorrectionUpdated_DLP(account, _pointsCorrection_DLP);
		emit PointsCorrectionUpdated_VDRCY(account, _pointsCorrection_VDRCY);
	}

	/**
        @dev   Burns an amount of the token of a given account. Updates pointsCorrection_DLP to keep funds unchanged.
        @dev   It emits a `PointsCorrectionUpdated` event.
        @param account The account whose tokens will be burnt.
        @param value   The amount that will be burnt.
    */
	function _burn(address account, uint256 value) internal virtual override {
		super._burn(account, value);

		int256 _pointsCorrection_DLP = pointsCorrection_DLP[account].add(
			(pointsPerShare_DLP.mul(value)).toInt256Safe()
		);

		pointsCorrection_DLP[account] = _pointsCorrection_DLP;

		int256 _pointsCorrection_VDRCY = pointsCorrection_VDRCY[account].add(
			(pointsPerShare_VDRCY.mul(value)).toInt256Safe()
		);

		pointsCorrection_VDRCY[account] = _pointsCorrection_VDRCY;

		emit PointsCorrectionUpdated_DLP(account, _pointsCorrection_DLP);
		emit PointsCorrectionUpdated_VDRCY(account, _pointsCorrection_VDRCY);
	}

	/**
        @dev Withdraws all available funds for a token holder.
    */
	function withdrawFunds_DLP() public virtual override {}

	function withdrawFunds_VDRCY() public virtual override {}

	function withdrawFunds() public virtual override {}

	/**
        @dev    Updates the current `fundsToken` balance and returns the difference of the new and previous `fundsToken` balance.
        @return A int256 representing the difference of the new and previous `fundsToken` balance.
    */
	function _updateFundsTokenBalance_DLP() internal virtual returns (int256) {}

	function _updateFundsTokenBalance_VDRCY() internal virtual returns (int256) {}

	/**
        @dev Registers a payment of funds in tokens. May be called directly after a deposit is made.
        @dev Calls _updateFundsTokenBalance(), whereby the contract computes the delta of the new and previous
             `fundsToken` balance and increments the total received funds (cumulative), by delta, by calling _distributeFunds_DLP().
    */
	function updateFundsReceived() public virtual {
		int256 newFunds_DLP = _updateFundsTokenBalance_DLP();
		int256 newFunds_VDRCY = _updateFundsTokenBalance_VDRCY();

		if (newFunds_DLP > 0) {
			_distributeFunds_DLP(newFunds_DLP.toUint256Safe());
		}

		if (newFunds_VDRCY > 0) {
			_distributeFunds_VDRCY(newFunds_VDRCY.toUint256Safe());
		}
	}

	function updateFundsReceived_DLP() public virtual {
		int256 newFunds_DLP = _updateFundsTokenBalance_DLP();

		if (newFunds_DLP > 0) {
			_distributeFunds_DLP(newFunds_DLP.toUint256Safe());
		}
	}

	function updateFundsReceived_VDRCY() public virtual {
		int256 newFunds_VDRCY = _updateFundsTokenBalance_VDRCY();

		if (newFunds_VDRCY > 0) {
			_distributeFunds_VDRCY(newFunds_VDRCY.toUint256Safe());
		}
	}

	function returnPointsCorrection_DLP(address _account) public view returns (int256) {
		return pointsCorrection_DLP[_account];
	}

	function returnPointsCorrection_VDRCY(address _account) public view returns (int256) {
		return pointsCorrection_VDRCY[_account];
	}

	function returnWithdrawnFunds_DLP(address _account) public view returns (uint256) {
		return withdrawnFunds_DLP[_account];
	}

	function returnWithdrawnFunds_VDRCY(address _account) public view returns (uint256) {
		return withdrawnFunds_VDRCY[_account];
	}
}
