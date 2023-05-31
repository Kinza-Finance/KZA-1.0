// SPDX-License-Identifier: AGPL-3.0
interface IPoolDataProvider {
    struct TokenData {
        string symbol;
        address tokenAddress;
    }
  function getAllATokens() external returns(TokenData[] memory);
}
