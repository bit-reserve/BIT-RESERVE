import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

pragma solidity 0.8.19;

interface IrBTC is IERC20Metadata {
    function currentBalance() external view returns (uint256);

    function deposit(
        address _restakedLST,
        address _to,
        uint256 _amount
    ) external;

    function redeem(
        address _restakedLSTToReceive,
        address _to,
        uint256 _rBTCToRedeem
    ) external;
}