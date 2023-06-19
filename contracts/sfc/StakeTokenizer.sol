pragma solidity ^0.5.0;

import "./SFC.sol";
import "../erc20/base/ERC20Burnable.sol";
import "../erc20/base/ERC20Mintable.sol";
import "../common/Initializable.sol";

contract Spacer {
    address private _owner;
}

contract StakeTokenizer is Spacer, Initializable {
    SFC internal sfc;

    mapping(address => mapping(uint256 => uint256)) public outstandingSSKH;

    address public sSKHTokenAddress;

    function initialize(address _sfc, address _sSKHTokenAddress) public initializer {
        sfc = SFC(_sfc);
        sSKHTokenAddress = _sSKHTokenAddress;
    }

    function mintSSKH(uint256 toValidatorID) external {
        address delegator = msg.sender;
        uint256 lockedStake = sfc.getLockedStake(delegator, toValidatorID);
        require(lockedStake > 0, "delegation isn't locked up");
        require(lockedStake > outstandingSSKH[delegator][toValidatorID], "sSKH is already minted");

        uint256 diff = lockedStake - outstandingSSKH[delegator][toValidatorID];
        outstandingSSKH[delegator][toValidatorID] = lockedStake;

        // It's important that we mint after updating outstandingSSKH (protection against Re-Entrancy)
        require(ERC20Mintable(sSKHTokenAddress).mint(delegator, diff), "failed to mint sSKH");
    }

    function redeemSSKH(uint256 validatorID, uint256 amount) external {
        require(outstandingSSKH[msg.sender][validatorID] >= amount, "low outstanding sSKH balance");
        require(IERC20(sSKHTokenAddress).allowance(msg.sender, address(this)) >= amount, "insufficient allowance");
        outstandingSSKH[msg.sender][validatorID] -= amount;

        // It's important that we burn after updating outstandingSSKH (protection against Re-Entrancy)
        ERC20Burnable(sSKHTokenAddress).burnFrom(msg.sender, amount);
    }

    function allowedToWithdrawStake(address sender, uint256 validatorID) public view returns(bool) {
        return outstandingSSKH[sender][validatorID] == 0;
    }
}
