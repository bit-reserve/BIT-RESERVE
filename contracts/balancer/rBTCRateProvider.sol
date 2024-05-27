pragma solidity ^0.8.0;

import "../interface/IERC20.sol";
import "../interface/balancer/IRateProvider.sol";

/**
 * @title rBTC Rate Provider
 * @notice Returns the value of srBTC in terms of rBTC
 */
contract srBTCRateProvider is IRateProvider {
    IERC20 public immutable rBTC;
    IERC20 public immutable srBTC;

    constructor(address _rBTC, address _srBTC) {
        rBTC = IERC20(_rBTC);
        srBTC = IERC20(_srBTC);
    }

    /**
     * @return uint256  the value of srBTC in terms of rBTC
     */
    function getRate() external view override returns (uint256) {
        return 1e18 * rBTC.balanceOf(address(srBTC)) / srBTC.totalSupply();
    }
}