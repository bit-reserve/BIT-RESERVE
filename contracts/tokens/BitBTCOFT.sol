// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import  "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

contract rBTC is OFT{

    /// DEPENDENCIES ///

    using SafeERC20 for IERC20;

    /// STATE VARIABLES ///

    /// @notice Array of approved restaked LSTs
    address[] public approvedRestakedLSTs;

    /// @notice Amount of total token deposited
    mapping(address => uint256) public totalRestakedLSTDeposited;
    /// @notice Amount of token managed
    mapping(address => uint256) public restakedLSTManaged;
    /// @notice Amount of rBTC for token
    mapping(address => uint256) public rBTCPerRestakedLST;
    /// @notice Address to send token to
    mapping(address => address) public routeRestakedLSTTo;
    /// @notice Bool if address is restaked LST
    mapping(address => bool) public restakedLST;
    /// @notice Bool if address is approved manager
    mapping(address => bool) public approvedManager;

    /// @notice Bool if redemtions are active
    bool public redemtionsActive;
    /// @notice Bool if deposits are open
    bool public depositsOpen;

    /// @notice Number of approved tokens
    uint256 public approvedTokens;

    uint256 public redeemFee =30;

    uint256 public constant feeRadix =10000;

    address redeemFeeTo;

    /// EVENTS ///

    event Deposit(address indexed staker, uint256 rBTCReceived);
    event Redeemed(address indexed staker, uint256 rBTCBurned);
    event TokenBalanceUpdated(address indexed token, uint256 newBalance);
    event RestakedLSTAdded(address tokenAdded, uint256 rBTCPerToken);
    event RestakedLSTRemoved(address tokenRemoved);
    event rBTCPerTokenUpdated(address restakedLST, uint256 rBTCPerToken);
    event TokenRouteUpdated(address restakedLST, address routedTo);
    event RedemtionsActivated();
    event RedemtionUnactivated();
    event ApprovedManagerAdded(address approvedManager);
    event ApprovedManagerRemoved(address removedManaged);
    event TokenManaged(address indexed byAddress, address indexed tokenManaged, uint256 amountManaged);
    event TokenManagedReaded(address indexed fromAddress, address indexed tokenAdded, uint256 amountAdded);
    event DepositsOpened();

    /// CONSTRUCTOR ///

    constructor( 
        address _lzEndpoint,
        address _delegate) OFT("BIT Reserve BTC","rBTC",_lzEndpoint,_delegate){
    }

    /// MUTATIVE FUNCTIONS ///

    /// @notice              Deposit `_restakedLST` to receive rBTC
    /// @param _restakedLST  Restaked LST to deposit
    /// @param _to           Address to send minted rBTC to
    /// @param _amount       Amount of `_restakedLST` to deposit
    function deposit(
        address _restakedLST,
        address _to,
        uint256 _amount
    ) external {
        if (!depositsOpen) require(msg.sender == owner(), "Deposits not open");
        require(restakedLST[_restakedLST], "Not approved restaked LST");
        require(_amount > 0, "Can not deposit 0");
        uint256 _amountToMint = (rBTCPerRestakedLST[_restakedLST] * _amount) /
            (10 ** IERC20Metadata(_restakedLST).decimals());
        _mint(_to, _amountToMint);
        emit Deposit(_to, _amountToMint);

        totalRestakedLSTDeposited[_restakedLST] += _amount;
        if (routeRestakedLSTTo[_restakedLST] == address(0)) {
            IERC20(_restakedLST).safeTransferFrom(
                _msgSender(),
                address(this),
                _amount
            );
        } else {
            IERC20(_restakedLST).safeTransferFrom(
                _msgSender(),
                routeRestakedLSTTo[_restakedLST],
                _amount
            );
            restakedLSTManaged[_restakedLST] += _amount;
        }
    }

    /// @notice                       Redeem rBTC to receive `_restakedLSTToReceive`
    /// @param _restakedLSTToReceive  Restaked LST to receive
    /// @param _to                    Address to send receive redeemed `_restakedLSTToReceive`
    /// @param _rBTCToRedeem          Amount of rBTC to redeem
    function redeem(
        address _restakedLSTToReceive,
        address _to,
        uint256 _rBTCToRedeem
    ) external {
        require(redemtionsActive, "Redemtions not active");
        require(restakedLST[_restakedLSTToReceive], "Not restaked LST");

        uint256 _restakedLSTToSend = ((10 **
            IERC20Metadata(_restakedLSTToReceive).decimals()) * _rBTCToRedeem) /
            rBTCPerRestakedLST[_restakedLSTToReceive];

        require(
            totalRestakedLSTDeposited[_restakedLSTToReceive] >=
                _restakedLSTToSend,
            "Not enough funds to redeem LST"
        );

        require(redeemFeeTo != address(0),"Not setting redeemFeeTo address");

        uint256 fees = _restakedLSTToSend * redeemFee / feeRadix;
        totalRestakedLSTDeposited[_restakedLSTToReceive] -= _restakedLSTToSend;
        _burn(_msgSender(), _rBTCToRedeem);

        if(fees !=0 )
             IERC20(_restakedLSTToReceive).safeTransfer(redeemFeeTo, fees);
        
        IERC20(_restakedLSTToReceive).safeTransfer(_to, _restakedLSTToSend - fees);
        emit Redeemed(_to, _rBTCToRedeem);
    }

    /// @notice              Update balaces of restaked LST
    /// @param _restakedLST  Address of restaked LST to update
    function updateDeposit(address _restakedLST) public {
        uint256 totalDepositsInContract = totalRestakedLSTDeposited[
            _restakedLST
        ] - restakedLSTManaged[_restakedLST];
        uint256 accruedLST = IERC20(_restakedLST).balanceOf(address(this)) -
            totalDepositsInContract;
        totalRestakedLSTDeposited[_restakedLST] += accruedLST;
        emit TokenBalanceUpdated(
            _restakedLST,
            totalRestakedLSTDeposited[_restakedLST]
        );
    }

    /// OWNER FUNCTION ///

    /// @notice              Add restaked LST
    /// @param _restakedLST  Address of restaked LST to add
    /// @param _rBTCPerLST   Amount of rBTC per `_restakedLST`
    function addRestakedLST(
        address _restakedLST,
        uint256 _rBTCPerLST
    ) external onlyOwner {
        require(!restakedLST[_restakedLST], "Already added");
        restakedLST[_restakedLST] = true;
        rBTCPerRestakedLST[_restakedLST] = _rBTCPerLST;
        approvedRestakedLSTs.push(_restakedLST);
        ++approvedTokens;
        emit RestakedLSTAdded(_restakedLST, _rBTCPerLST);
    }

    /// @notice              Remove `_restakedLST`
    /// @param _restakedLST  Address of restaked LST to remove
    function removeRestakedLST(address _restakedLST) external onlyOwner {
        require(restakedLST[_restakedLST], "Not restaked LST");
        restakedLST[_restakedLST] = false;
        rBTCPerRestakedLST[_restakedLST] = 0;

        uint256 _arrLength = approvedRestakedLSTs.length;
        for (uint i; i < _arrLength; ++i) {
            if (approvedRestakedLSTs[i] == _restakedLST) {
                approvedRestakedLSTs[i] = approvedRestakedLSTs[_arrLength - 1];
                approvedRestakedLSTs.pop();
                break;
            }
        }
        --approvedTokens;

        emit RestakedLSTRemoved(_restakedLST);
    }

    /// @notice              Update amount of rBTC per `_restakedLST`
    /// @param _restakedLST  Address of restaked LST to update `_rBTCPerLST` for
    /// @param _rBTCPerLST   Amount of rBTC per `_restakedLST`
    function updaterBTCPerLST(
        address _restakedLST,
        uint256 _rBTCPerLST
    ) external onlyOwner {
        require(restakedLST[_restakedLST], "Not restaked LST");
        rBTCPerRestakedLST[_restakedLST] = _rBTCPerLST;
        emit rBTCPerTokenUpdated(_restakedLST, _rBTCPerLST);
    }

    /// @notice              Update address to route `_restakedLST` to
    /// @param _restakedLST  Address of restaked LST to add where to route
    /// @param _where        Address of where to route `_restakedLST`
    function updateRouteRestakedLSTTo(
        address _restakedLST,
        address _where
    ) external onlyOwner {
        require(restakedLST[_restakedLST], "Not restaked LST");
        routeRestakedLSTTo[_restakedLST] = _where;
        emit TokenRouteUpdated(_restakedLST, _where);
    }

    /// @notice  Set redemtions active
    function setRedemtionActive() external onlyOwner {
        redemtionsActive = true;
        emit RedemtionsActivated();
    }

    /// @notice  Set redemtions unactive
    function setRedemtionUnactive() external onlyOwner {
        redemtionsActive = false;
        emit RedemtionUnactivated();
    }

    /// @notice  Add approved manager
    function addApprovedManager(address _manager) external onlyOwner {
        approvedManager[_manager] = true;
        emit ApprovedManagerAdded(_manager);
    }

    /// @notice  Remove approved manage
    function removeApprovedManager(address _manager) external onlyOwner {
        approvedManager[_manager] = false;
        emit ApprovedManagerRemoved(_manager);
    }

    /// @notice         Recover tokens
    /// @param _to      Address to send recovered tokens
    /// @param _token   Address of token to recover
    /// @param _amount  Amount of token to recover
    function recoverTokens(
        address _to,
        address _token,
        uint256 _amount
    ) external onlyOwner {
        require(!restakedLST[_token], "Can Not transfer restaked LST");
        IERC20(_token).safeTransfer(_to, _amount);
    }

    /// @notice Open deposits
    function openDeposits() external onlyOwner {
        require(!depositsOpen, "Deposits already opened");
        depositsOpen = true;
        emit DepositsOpened();
    }


    function setRedemFee(uint newFee) external onlyOwner(){
        require(newFee< 51,"Fees to large");
        redeemFee = newFee;
    }

    function setRedemFeeTo(address _feeTo) external onlyOwner(){
        redeemFeeTo = _feeTo;
    }
    /// MANAGER FUNCTIONS ///

    /// @notice              Manage restaked LST
    /// @param _restakedLST  Address of restaked LST to manage
    /// @param _to           Address of where to send `_amount` of `_restakedLST`
    /// @param _amount       Amount to manage
    function manageRestakedLST(
        address _restakedLST,
        address _to,
        uint256 _amount
    ) external {
        require(approvedManager[msg.sender], "Not approved manager");
        require(restakedLST[_restakedLST], "Not restaked LST");
        updateDeposit(_restakedLST);
        IERC20(_restakedLST).safeTransfer(_to, _amount);
        restakedLSTManaged[_restakedLST] += _amount;

        emit TokenManaged(msg.sender, _restakedLST, _amount);
    }

    /// @notice              Add back managed restaked LST
    /// @param _restakedLST  Address of restaked LST to add back
    /// @param _amount       Amount to add back manage
    function addMangedRestakedLST(
        address _restakedLST,
        uint256 _amount
    ) external {
        require(approvedManager[msg.sender], "Not approved manager");
        require(restakedLST[_restakedLST], "Not restaked LST");
        if (_amount > restakedLSTManaged[_restakedLST])
            restakedLSTManaged[_restakedLST] = 0;
        else restakedLSTManaged[_restakedLST] -= _amount;

        IERC20(_restakedLST).safeTransferFrom(msg.sender, address(this), _amount);
        emit TokenManagedReaded(msg.sender, _restakedLST, _amount);
    }

    /// VIEW FUNCTIONS ///

    /// @notice              Returns amount of `_restakedLST` the contract has, including that being managed
    /// @param _restakedLST  Address of restaked LST to check balance for
    /// @return _balance     Balance of `_restakedLST` for contract
    function currentBalance(
        address _restakedLST
    ) external view returns (uint256 _balance) {
        uint256 totalDepositsInContract = totalRestakedLSTDeposited[
            _restakedLST
        ] - restakedLSTManaged[_restakedLST];
        uint256 accruedLST = IERC20(_restakedLST).balanceOf(address(this)) -
            totalDepositsInContract;
        return totalRestakedLSTDeposited[_restakedLST] + accruedLST;
    }
}
