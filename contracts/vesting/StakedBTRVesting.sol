pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interface/IStaking.sol";

contract StakedBTRVesting is Ownable {
    /// DEPENDENCIES ///

    using SafeERC20 for IERC20;

    /// STRUCTS ///

    struct Term {
        uint256 indexAdjustedClaimed;        // Rebase-tracking number claimed
        uint256 totalIndexAdjustedCanClaim;  // Total amount of index adjusted sBTR can claim
        uint256 startVest;                   // Timestamp vesting start
        uint256 endVest;                     // Timestamp vesting ended
        uint256 vestLength;                  // Vesting length
    }

    /// STATE VARIABLES ///

    /// @notice BTR token
    IERC20 internal immutable BTR;
    /// @notice sBTR Claim Token
    IERC20 internal immutable sBTR;
    /// @notice Stake BTR for sBTR
    IStaking internal immutable staking;

    /// @notice Tracks address term info
    mapping(address => Term) public terms;
    /// @notice Tracks address change
    mapping(address => address) public walletChange;

    /// CONSTRUCTOR ///

    constructor(address _BTR, address _sBTR, address _staking) {
        BTR = IERC20(_BTR);
        sBTR = IERC20(_sBTR);
        staking = IStaking(_staking);

        IERC20(_BTR).approve(_staking, type(uint256).max);
    }

    /// MUTABLE FUNCTIONS ///

    /// @notice         Logic for claiming sBTR
    /// @param _to      Address to send sBTR to
    /// @param _amount  Amount of sBTR to send
    function claim(address _to, uint256 _amount) external {
        require(redeemableFor(msg.sender) >= _amount, "Claim more than vested");
        sBTR.safeTransfer(_to, _amount);

        terms[msg.sender].indexAdjustedClaimed += toIndexAdjusted(_amount);
    }

    /// WALLET CHANGES ///

    /// @notice             Allows address to push terms to new address
    /// @param _newAddress  New wallets address
    function pushWalletChange(address _newAddress) external {
        require(
            terms[msg.sender].totalIndexAdjustedCanClaim != 0,
            "No wallet to change"
        );
        walletChange[msg.sender] = _newAddress;
    }

    /// @notice             Allows new address to pull terms
    /// @param _oldAddress  Old address to pull terms for
    function pullWalletChange(address _oldAddress) external {
        require(
            walletChange[_oldAddress] == msg.sender,
            "Old wallet did not push"
        );
        require(
            terms[msg.sender].totalIndexAdjustedCanClaim == 0,
            "Wallet already exists"
        );

        walletChange[_oldAddress] = address(0);
        terms[msg.sender] = terms[_oldAddress];
        delete terms[_oldAddress];
    }

    /// VIEW FUNCTIONS ///

    /// @notice          Returns % of overall vesting completed for `_address`
    /// @param _address  Address to check percent vested for
    /// @return uint     Percent of vesting for `_address` 1e8 == 10%
    function percentVested(address _address) public view returns (uint256) {
        Term memory info = terms[_address];
        if (block.timestamp > info.endVest) return 18;

        uint256 timeSinceVestStart = block.timestamp - info.startVest;

        return (1e18 * timeSinceVestStart) / info.vestLength;
    }

    /// @notice             View sBTR redeemable for `_address`
    /// @param _address     Redeemable for address
    /// @return _canRedeem  sBTR redeemable for `_address`
    function redeemableFor(
        address _address
    ) public view returns (uint256 _canRedeem) {
        Term memory info = terms[_address];
        uint256 totalReedemable = (info.totalIndexAdjustedCanClaim *
            percentVested(_address)) / 1e18;

        _canRedeem = fromIndexAdjusted(
            totalReedemable - info.indexAdjustedClaimed
        );
    }

    /// @notice         Converts index adjusted amount to BTR
    /// @param _amount  Index adjusted amount to get static of
    /// @return uint    Satic amount for index adjusted `_amount`
    function fromIndexAdjusted(uint256 _amount) public view returns (uint256) {
        return (_amount * staking.index()) / 1e18;
    }

    /// @notice         Converts BTR to index adjusted amount
    /// @param _amount  Static amount to get index adjusted of
    /// @return uint    Index adjusted amount for static `_amount`
    function toIndexAdjusted(uint256 _amount) public view returns (uint256) {
        return (_amount * 1e18) / staking.index();
    }

    /// @notice          View sBTR claimed for `_address`
    /// @param _address  Claimed for address
    /// @return uint256  sBTR claimed for `_address`
    function claimed(address _address) public view returns (uint256) {
        return fromIndexAdjusted(terms[_address].indexAdjustedClaimed);
    }

    /// OWNER FUNCTIONS ///

    /// @notice                    Set terms for new address
    /// @param _address            Address of who to set terms for
    /// @param _BTRToStakeAndVest  Amount of BTR to stake and vest for `_address`
    /// @param _vestLength         Vest length for `_address`
    function setTerms(
        address _address,
        uint256 _BTRToStakeAndVest,
        uint256 _vestLength
    ) external onlyOwner {
        require(
            terms[_address].totalIndexAdjustedCanClaim == 0,
            "Address already exists"
        );

        BTR.safeTransferFrom(msg.sender, address(this), _BTRToStakeAndVest);
        staking.stake(address(this), _BTRToStakeAndVest);
        uint256 _indexAdjusted = toIndexAdjusted(_BTRToStakeAndVest);
        terms[_address] = Term({
            indexAdjustedClaimed: 0,
            totalIndexAdjustedCanClaim: _indexAdjusted,
            startVest: block.timestamp,
            endVest: block.timestamp + _vestLength,
            vestLength: _vestLength
        });
    }
}
