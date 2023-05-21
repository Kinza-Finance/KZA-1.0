contract MockRewardOracle {
    function latestAnswer() public view returns(uint256) {
        return 1;
    }
    function decimals() external view returns (uint8) {
        return 18;
    }

  function latestTimestamp() external view returns (uint256 x) {

  }

  function latestRound() external view returns (uint256 x) {

  }

  function getAnswer(uint256 roundId) external view returns (int256 x) {

  }

  function getTimestamp(uint256 roundId) external view returns (uint256 x) {

  }
}