// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IXKZA {
    struct RedeemInfo {
        uint256 amount; //  amount to receive when vesting has ended
        uint256 xAmount; // xToken amount to redeem
        uint256 endTime;
    }

    function getUserRedeemsLength(address _userAddress) external view returns (uint256);

    function userRedeems(address _userAddress, uint256 _redeemIndex) external view returns (RedeemInfo memory);

    function voter() external view returns (address);
}

interface IMarketVoter {
    function marketLength() external view returns (uint256);

    function markets(uint256 _index) external view returns (address);

    function votes(address _user, address _market) external view returns (uint256);
}

contract VoteDataProvider {
    address public xKZA;
    address public voter;

    constructor(address _xKZA) {
        xKZA = _xKZA;
        voter = IXKZA(xKZA).voter();
    }

    function getUserAllRedeems(address _userAddress) external view returns (IXKZA.RedeemInfo[] memory) {
        uint256 length = IXKZA(xKZA).getUserRedeemsLength(_userAddress);

        IXKZA.RedeemInfo[] memory redeemInfos = new IXKZA.RedeemInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            redeemInfos[i] = IXKZA(xKZA).userRedeems(_userAddress, i);
        }

        return redeemInfos;
    }

    function getVoterMarkets() public view returns (address[] memory) {
        uint256 length = IMarketVoter(voter).marketLength();

        address[] memory markets = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            markets[i] = IMarketVoter(voter).markets(i);
        }

        return markets;
    }

    function getUserAllVotes() external view returns (address[] memory, uint256[] memory) {
        address[] memory markets = getVoterMarkets();

        uint256[] memory votes = new uint256[](markets.length);

        for (uint256 i = 0; i < markets.length; i++) {
            votes[i] = IMarketVoter(voter).votes(msg.sender, markets[i]);
        }

        return (markets, votes);
    }
}
