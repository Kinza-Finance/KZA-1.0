pragma solidity 0.8.17;
interface ITransferStrategyBase {
    function performTransfer(address to, address reward, uint256 amount) external returns(bool);
}