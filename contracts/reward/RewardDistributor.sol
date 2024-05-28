// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interface/IBTR.sol";
import "../interface/IrBTC.sol";
import "../interface/ICoreBTC.sol";
import "../interface/ITreasury.sol";

/// @title   Distributor
/// @notice  BTR Staking Distributor
contract Distributor is Ownable {
    /// EVENTS ///

    event BTRRateSet(uint256 oldRate, uint256 newRate);
    event rBTCRewardSet(uint256 oldReward, uint256 newReward);

    /// VARIABLES ///

    /// @notice BTR address
    IERC20 public immutable BTR;
    /// @notice Treasury address
    ITreasury public immutable treasury;
    /// @notice Staking address
    address public immutable btrStaking;
    /// @notice coreBTC address
    address public immutable coreBTC;
    /// @notice rBTC address
    address public immutable rBTC;
    /// @notice srBTC address
    address public immutable srBTC;

    /// @notice In ten-thousandths ( 5000 = 0.5% )
    uint256 public btrRate;
    /// @notice Amount of coreBTC sent to srBTC every epoch
    uint256 public srBTCRewardPerEpoch;
    /// @notice Total coreBTC torwards srBTC
    uint256 public historicalYield;

    uint256 public constant rateDenominator = 1_000_000;

    /// CONSTRUCTOR ///

    /// @param _treasury    Address of treasury contract
    /// @param _BTR         Address of BTR
    /// @param _rBTC        Address of rBTC
    /// @param _srBTC       Address of srBTC
    /// @param _btrStaking  Address of staking contract
    constructor(
        address _treasury,
        address _BTR,
        address _rBTC,
        address _srBTC,
        address _btrStaking
    ) {
        // todo 
        coreBTC = 0x349507EF6bc6311d1fF6D633BfbBEdf69d7eB28A;
        treasury = ITreasury(_treasury);
        BTR = IBTR(_BTR);
        rBTC = _rBTC;
        srBTC = _srBTC;
        btrStaking = _btrStaking;
    }

    /// STAKING FUNCTION ///

    /// @notice Send epoch reward to staking contract and srBTC reward
    function distribute() external {
        require(msg.sender == btrStaking, "Only staking");
        treasury.mint(btrStaking, nextBTRReward()); // mint and send tokens
        //if (address(this).balance > 0) ICoreBTC(coreBTC).deposit{value: address(this).balance}();
        if (srBTCRewardPerEpoch == 0 || IERC20(coreBTC).balanceOf(address(this)) == 0) return;

        if(IERC20(coreBTC).balanceOf(address(this)) >= srBTCRewardPerEpoch) {
            historicalYield += srBTCRewardPerEpoch;
            IrBTC(rBTC).deposit(coreBTC, srBTC, srBTCRewardPerEpoch);
        } else {
            historicalYield += IERC20(coreBTC).balanceOf(address(this));
            IrBTC(rBTC).deposit(coreBTC, srBTC, IERC20(coreBTC).balanceOf(address(this)));
        }
    }

    /// VIEW FUNCTIONS ///

    /// @notice          Returns next reward at given rate
    /// @param _rate     Rate
    /// @return _reward  Next reward
    function nextRewardAt(uint256 _rate) public view returns (uint256 _reward) {
        return (BTR.totalSupply() * _rate) / rateDenominator;
    }

    /// @notice          Returns next reward of staking contract
    /// @return _reward  Next reward for staking contract
    function nextBTRReward() public view returns (uint256 _reward) {
        uint256 excessReserves = treasury.excessReserves();
        _reward = nextRewardAt(btrRate);
        if (excessReserves < _reward) _reward = excessReserves;
    }

    /// POLICY FUNCTIONS ///

    /// @notice             Set reward rate for rebase
    /// @param _rewardRate  New rate
    function setBTRRate(uint256 _rewardRate) external onlyOwner {
        require(
            _rewardRate <= rateDenominator,
            "Rate cannot exceed denominator"
        );
        uint256 _oldRate = btrRate;
        btrRate = _rewardRate;
        emit BTRRateSet(_oldRate, _rewardRate);
    }

    /// @notice            Set reward for srBTC
    /// @param _newReward  New rate
    function setsrBTCReward(uint256 _newReward) external onlyOwner {
        IERC20(coreBTC).approve(rBTC, type(uint256).max);
        uint256 _oldReward = srBTCRewardPerEpoch;
        srBTCRewardPerEpoch = _newReward;
        emit rBTCRewardSet(_oldReward, _newReward);
    }

    /// @notice Withdraw token from contract
    function withdrawToken(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(_to, _amount);
    }

    /// @notice Withdraw stuck BTC from contract
    function withdrawStuckEth(address toAddr) external onlyOwner {
        (bool success, ) = toAddr.call{value: address(this).balance}("");
        require(success);
    }

    /// RECEIVE ///

    receive() external payable {}
}
