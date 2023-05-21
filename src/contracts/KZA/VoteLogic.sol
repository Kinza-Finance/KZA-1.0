// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/access/Ownable.sol";
import "../../interfaces/IXToken.sol";

// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\


/// @notice XKZA - Kinza protocol VoteLogic
/// @title VoteLogic
/// @notice VoteLogic is a contract that calculates the voting power of a user
///         based on the xKZA balance
///         and the redeeming position (with some discount)
contract VoteLogic is Ownable {

    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private constant PRECISION = 10000;
    IXToken public immutable XToken;

    /*//////////////////////////////////////////////////////////////
                        STORAGE VAARIABLE
    //////////////////////////////////////////////////////////////*/

    // XToken in the process of redeem is counted only as 50%.
    uint256 public countAs = 5000;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/
    event NewDiscountAs(uint256 newCountAs);

    constructor(
        address _xKZA,
        address _governance
    ) {
        XToken = IXToken(_xKZA);
        transferOwnership(_governance);

    }

    /*//////////////////////////////////////////////////////////////
                         OWNABLE FUNCTION
    //////////////////////////////////////////////////////////////*/
    /// @param _newCountAs new ratio for the xToken on voting
    function updateCountAs(uint256 _newCountAs) external onlyOwner {
        require(_newCountAs <= PRECISION, "discount out of bound");
        countAs = _newCountAs;
        emit NewDiscountAs(_newCountAs);
    }

    /// @notice return a balance accounting xToken balance and 
    ///         redeeming position with discount
    /// @return total balance 
    function balanceOf(address _xTokenHolder) public view returns(uint256) {
        uint256 currentBalance = XToken.balanceOf(_xTokenHolder);

        uint256 length = XToken.getUserRedeemsLength(_xTokenHolder);
        // no redeeming position
        if (length == 0) {
          return currentBalance;  
        // have redeem position
        } else {
            uint256 xTokenInRedeem;
            for (uint256 i; i < length ; ++i) {
                (,uint256 xAmount,) = XToken.getUserRedeem(_xTokenHolder, i);
                xTokenInRedeem += xAmount;
            }
            return currentBalance + xTokenInRedeem * countAs / PRECISION;
        }
        
    }
}