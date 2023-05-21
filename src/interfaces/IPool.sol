// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import '../libraries/DataTypes.sol';

interface IPool {
  
  function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);


  function getReservesList() external view returns (address[] memory);

  function mintToTreasury(address[] calldata _assets) external;
}
