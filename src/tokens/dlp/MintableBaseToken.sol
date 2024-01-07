// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "./BasicFDT.sol";
import "../../interfaces/tokens/dlp/IMintable.sol";
import "../../core/AccessControlBase.sol";
import "solmate/utils/ReentrancyGuard.sol";

contract MintableBaseToken is BasicFDT, AccessControlBase, ReentrancyGuard, IMintable {
	using SafeMath for uint256;
	using SafeMathUint for uint256;
	using SignedSafeMath for int256;
	using SafeMathInt for int256;

	mapping(address => bool) public override isMinter;
	bool public inPrivateTransferMode;
	mapping(address => bool) public isHandler;

	IERC20 public immutable rewardToken_DLP; // 1 The `rewardToken_DLP` (dividends).
	IERC20 public immutable rewardToken_VDRCY; // 2 The `rewardToken_VDRCY` (dividends).

	uint256 public rewardTokenBalance_DLP; // The amount of `rewardToken_DLP` (Liquidity Asset 1) currently present and accounted for in this contract.
	uint256 public rewardTokenBalance_VDRCY; // The amount of `rewardToken_VDRCY` (Liquidity Asset2 ) currently present and accounted for in this contract.

	event SetInfo(string name, string symbol);

	event SetPrivateTransferMode(bool inPrivateTransferMode);

	event SetHandler(address handlerAddress, bool isActive);

	event WithdrawStuckToken(address tokenAddress, address receiver, uint256 amount);

	constructor(
		string memory _name,
		string memory _symbol,
		address _vdrcyAddress,
		address _vaultRegistry,
		address _timelock
	) BasicFDT(_name, _symbol) AccessControlBase(_vaultRegistry, _timelock) {
		rewardToken_DLP = IERC20(address(this));
		rewardToken_VDRCY = IERC20(_vdrcyAddress);
	}

	modifier onlyMinter() {
		require(isMinter[_msgSender()], "MintableBaseToken: forbidden");
		_;
	}

	/**
        @dev Withdraws all available funds for a token holder.
    */
	function withdrawFunds_DLP() public virtual override nonReentrant {
		uint256 withdrawableFunds_DLP = _prepareWithdraw_DLP();

		if (withdrawableFunds_DLP > uint256(0)) {
			rewardToken_DLP.transfer(_msgSender(), withdrawableFunds_DLP);

			_updateFundsTokenBalance_DLP();
		}
	}

	function withdrawFunds_VDRCY() public virtual override nonReentrant {
		uint256 withdrawableFunds_VDRCY = _prepareWithdraw_VDRCY();

		if (withdrawableFunds_VDRCY > uint256(0)) {
			rewardToken_VDRCY.transfer(_msgSender(), withdrawableFunds_VDRCY);

			_updateFundsTokenBalance_VDRCY();
		}
	}

	function withdrawFunds() public virtual override nonReentrant {
		withdrawFunds_DLP();
		withdrawFunds_VDRCY();
	}

	/**
        @dev    Updates the current `rewardToken_DLP` balance and returns the difference of the new and previous `rewardToken_DLP` balance.
        @return A int256 representing the difference of the new and previous `rewardToken_DLP` balance.
    */
	function _updateFundsTokenBalance_DLP() internal virtual override returns (int256) {
		uint256 _prevFundsTokenBalance_DLP = rewardTokenBalance_DLP;

		rewardTokenBalance_DLP = rewardToken_DLP.balanceOf(address(this));

		return int256(rewardTokenBalance_DLP).sub(int256(_prevFundsTokenBalance_DLP));
	}

	function _updateFundsTokenBalance_VDRCY() internal virtual override returns (int256) {
		uint256 _prevFundsTokenBalance_VDRCY = rewardTokenBalance_VDRCY;

		rewardTokenBalance_VDRCY = rewardToken_VDRCY.balanceOf(address(this));

		return int256(rewardTokenBalance_VDRCY).sub(int256(_prevFundsTokenBalance_VDRCY));
	}

	function transfer(address _recipient, uint256 _amount) public override returns (bool) {
		if (inPrivateTransferMode) {
			require(isHandler[_msgSender()], "BaseToken: _msgSender() not whitelisted");
		}
		super._transfer(_msgSender(), _recipient, _amount);
		return true;
	}

	function transferFrom(
		address _from,
		address _recipient,
		uint256 _amount
	) public override returns (bool) {
		if (inPrivateTransferMode) {
			require(isHandler[_msgSender()], "BaseToken: _msgSender() not whitelisted");
		}
		if (isHandler[_msgSender()]) {
			super._transfer(_from, _recipient, _amount);
			return true;
		}
		address spender = _msgSender();
		super._spendAllowance(_from, spender, _amount);
		super._transfer(_from, _recipient, _amount);
		return true;
	}

	function setInPrivateTransferMode(
		bool _inPrivateTransferMode
	) external onlyTimelockGovernance {
		inPrivateTransferMode = _inPrivateTransferMode;
		emit SetPrivateTransferMode(_inPrivateTransferMode);
	}

	function setHandler(address _handler, bool _isActive) external onlyTimelockGovernance {
		isHandler[_handler] = _isActive;
		emit SetHandler(_handler, _isActive);
	}

	function setInfo(string memory _name, string memory _symbol) external onlyGovernance {
		_name = _name;
		_symbol = _symbol;
		emit SetInfo(_name, _symbol);
	}

	/**
	 * @notice function to service users who accidentally send their tokens to this contract
	 * @dev since this function could technically steal users assets we added a timelock modifier
	 * @param _token address of the token to be recoved
	 * @param _account address the recovered tokens will be sent to
	 * @param _amount amount of token to be recoverd
	 */
	function withdrawToken(
		address _token,
		address _account,
		uint256 _amount
	) external onlyGovernance {
		IERC20(_token).transfer(_account, _amount);
		emit WithdrawStuckToken(_token, _account, _amount);
	}

	function setMinter(
		address _minter,
		bool _isActive
	) external override onlyTimelockGovernance {
		isMinter[_minter] = _isActive;
		emit MinterSet(_minter, _isActive);
	}

	function mint(address _account, uint256 _amount) external override nonReentrant onlyMinter {
		super._mint(_account, _amount);
	}

	function burn(address _account, uint256 _amount) external override nonReentrant onlyMinter {
		super._burn(_account, _amount);
	}
}
