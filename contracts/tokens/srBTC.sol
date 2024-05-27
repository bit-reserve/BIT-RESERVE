pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract StakedrBTC is ERC20("Staked rBTC", "srBTC") {

    /// EVENTS ///

    event Stake(address indexed staker, uint256 srBTC);
    event Unstake(address indexed unstaker, uint256 rBTCReceived);

    /// STATE VARIABLE ///

    IERC20 public immutable rBTC;
    address public immutable deployer;

    /// CONSTRUCTOR ///

    constructor(IERC20 _rBTC) {
        rBTC = _rBTC;
        deployer = msg.sender;
    }

    /// STAKE ///

    function stake(uint256 _amount) public {
        uint256 totalrBTC = rBTC.balanceOf(address(this));
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || totalrBTC == 0) {
            require(msg.sender == deployer, "Deployer to be first stake to initialize proper shares");
            _mint(_msgSender(), _amount);
            emit Stake(_msgSender(), _amount);
        } else {
            uint256 _shares = _amount * totalShares / totalrBTC;
            _mint(_msgSender(), _shares);
            emit Stake(_msgSender(), _shares);
        }
        rBTC.transferFrom(_msgSender(), address(this), _amount);
    }

    /// UNSTAKE ///

    function unstake(uint256 _share) public {
        uint256 totalShares = totalSupply();
        uint256 _amount =
            _share * rBTC.balanceOf(address(this)) / totalShares;
        _burn(_msgSender(), _share);
        rBTC.transfer(_msgSender(), _amount);
        emit Unstake(_msgSender(), _amount);
    }
}