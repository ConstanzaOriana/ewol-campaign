// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 < 0.9.0;

import "./IEwolCampaignPrototype.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
/// @title Ewol Campaign Prototype
/// @author heidrian.eth
/// @notice This contract is used as prototype to clone each Ewol Academy Web3 Bootcamp campaign
contract EwolCampaignPrototype is IEwolCampaignPrototype, OwnableUpgradeable, ERC20Upgradeable {

  enum Period { Investment, Bootcamp, Repayment }

  /// @notice Target quantity of Ewolers to raise funding for
  uint16 public targetEwolers;

  /// @notice Amount of currency to be raised per Ewoler
  uint256 public investmentPerEwoler;
  
  /// @notice Address of the ERC20 token used as campaign currency
  address public currencyToken;
  
  /// @notice Number of weeks of the bootcamp
  uint8 public weeksOfBootcamp;

  /// @notice Current period for the campaign (Investment, Bootcamp or Repayment)
  Period public currentPeriod;

  /// @notice Total amount of currency tokens invested
  uint256 public totalInvested;

  /// @notice Wallet address for each ewoler
  mapping (uint256 => address) public ewolerAddress;

  /// @notice Total amount to be released per week of Bootcamp for each ewoler
  mapping (uint256 => uint256) public ewolerWeeklyExpenditure;

  /// @notice Total amount already withdrawn by the ewoler
  mapping (uint256 => uint256) public ewolerWithdrawals;

  /// @notice Wallet address for each staff member
  mapping (uint256 => address) public stafferAddress;

  /// @notice Total amount to be released per week of Bootcamp for each staff member
  mapping (uint256 => uint256) public stafferWeeklyExpenditure;

  /// @notice Total amount already withdrawn by each staff member
  mapping (uint256 => uint256) public stafferWithdrawals;

  /// @notice Total amount to be released per week for ewolers and staff members
  uint256 public totalWeeklyExpenditure;

  /// @notice Timestamp of the start of the bootcamp
  uint256 public bootcampStart;

  /// @notice Total amount of expenditure paid to ewolers or staff members
  uint256 public totalExpendituresWithdrawn;

  modifier onlyPeriod (Period _period) {
    require(currentPeriod == _period, "Method not available for this period");
    _;
  }

  /// @notice Initialize the new campaign
  /// @dev 
  /// @param _campaignName        Name of the Ewol Campaign
  /// @param _targetEwolers       Target quantity of Ewolers to raise funding for
  /// @param _investmentPerEwoler Amount of currency to be raised per Ewoler
  /// @param _currencyToken       Address of the ERC20 token used as campaign currency
  /// @param _weeksOfBootcamp     Number of weeks of the bootcamp
  /// @param _premintAmount       Amount of campaign tokens preminted for the campaign launcher
  /// @param _owner               The initial campaign owner
  function init (
    string calldata _campaignName,
    uint16 _targetEwolers,
    uint256 _investmentPerEwoler,
    address _currencyToken,
    uint8 _weeksOfBootcamp,
    uint256 _premintAmount,
    address _owner
  ) initializer public virtual override {

    // Initalizes the inherited upgradeable (no constructor) contracts
    __ERC20_init(_campaignName, "cEWOL");

    // Saves campaign data for future use
    targetEwolers = _targetEwolers;
    investmentPerEwoler = _investmentPerEwoler;
    currencyToken = _currencyToken;
    weeksOfBootcamp = _weeksOfBootcamp;

    // Premints tokens for campaign owner
    _mint(_owner, _premintAmount);

    // Sets the campaign owner
    _transferOwnership(_owner);

    currentPeriod = Period.Investment;
  }

  /// @notice Total to invest in this campaign
  /// @dev 
  /// @return Total to invest in this campaign
  function investmentCap () public virtual override view returns (uint256) {
    return targetEwolers * investmentPerEwoler;
  }

  /// @notice Deposit tokens to invest in the campaign
  /// @dev The contract will include a list of prevetted tokens
  /// @param _depositToken  Address of the ERC20 token used to fund the investment
  /// @param _amount        Amount to deposit of the `_depositToken`
  function depositInvestment (
    address _depositToken,
    uint256 _amount
  ) public virtual override onlyPeriod(Period.Investment) {
    require(currencyToken == _depositToken, "Deposit token not supported");
    require(_amount <= investmentCap() - totalInvested, "Deposit exceeds investment cap");
    SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(_depositToken), msg.sender, address(this), _amount);
    totalInvested += _amount;
    _mint(msg.sender, _amount);
  }

  /// @notice Enroll an Ewoler in the campaign
  /// @param _ewolerId          ID for the ewoler
  /// @param _ewolerAddress     Address of the ewoler wallet
  /// @param _weeklyExpenditure Amount of currency tokens to be released per week as expenditure
  function enrollEwoler (
    uint256 _ewolerId,
    address _ewolerAddress,
    uint256 _weeklyExpenditure
  ) public virtual override onlyOwner onlyPeriod(Period.Investment) {
    require(_ewolerAddress != address(0), "Ewoler address can't be zero");
    require(ewolerAddress[_ewolerId] == address(0), "Ewoler already enrolled");
    ewolerAddress[_ewolerId] = _ewolerAddress;
    ewolerWeeklyExpenditure[_ewolerId] = _weeklyExpenditure;
    totalWeeklyExpenditure += _weeklyExpenditure;
  }

  /// @notice Enroll an Ewol Staff Member in the campaign
  /// @param _stafferId         ID for the staffer
  /// @param _stafferAddress    Address of the staffer wallet
  /// @param _weeklyExpenditure Amount of currency tokens to be released per week as expenditure
  /// @param _variableComp      Variable compensation denominated in campaign tokens
  function enrollStaff (
    uint256 _stafferId,
    address _stafferAddress,
    uint256 _weeklyExpenditure,
    uint256 _variableComp
  ) public virtual override onlyOwner onlyPeriod(Period.Investment) {
    require(_stafferAddress != address(0), "Staffer address can't be zero");
    require(stafferAddress[_stafferId] == address(0), "Staffer already enrolled");
    stafferAddress[_stafferId] = _stafferAddress;
    stafferWeeklyExpenditure[_stafferId] = _weeklyExpenditure;
    _mint(_stafferAddress, _variableComp);
    totalWeeklyExpenditure += _weeklyExpenditure;
  }

  /// @notice Remove an Ewoler from the campaign
  /// @param _ewolerId          ID for the ewoler
  function removeEwoler (
    uint256 _ewolerId
  ) public virtual override onlyOwner {
    require(currentPeriod != Period.Repayment, "Bootcamp already concluded");
    require(ewolerAddress[_ewolerId] != address(0), "Staffer was never enrolled");

    ewolerAddress[_ewolerId] = address(0);

    uint256 _weeklyExpenditure = ewolerWeeklyExpenditure[_ewolerId];
    ewolerWeeklyExpenditure[_ewolerId] = 0;
    totalWeeklyExpenditure -= _weeklyExpenditure;
  }

  /// @notice Remove an Ewol Staff Member from the campaign
  /// @param _stafferId         ID for the staffer
  function removeStaff (
    uint256 _stafferId
  ) public virtual override onlyOwner {
    require(currentPeriod != Period.Repayment, "Bootcamp already concluded");
    require(stafferAddress[_stafferId] != address(0), "Staffer was never enrolled");

    address _stafferAddress = stafferAddress[_stafferId];
    stafferAddress[_stafferId] = address(0);

    uint256 _weeklyExpenditure = stafferWeeklyExpenditure[_stafferId];
    stafferWeeklyExpenditure[_stafferId] = 0;
    totalWeeklyExpenditure -= _weeklyExpenditure;

    _burn(_stafferAddress, balanceOf(_stafferAddress));    
  }

  /// @notice Start the Bootcamp period
  function startBootcamp () public virtual override onlyOwner onlyPeriod(Period.Investment) {
    require(totalInvested >= totalWeeklyExpenditure * weeksOfBootcamp, "Not enough funds to start Bootcamp");
    currentPeriod = Period.Bootcamp;
    bootcampStart = block.timestamp;
  }

  function _weeksOfBootcampElapsed() private view returns(uint256) {
    require(bootcampStart > 0, "Bootcamp hasn't started");
    uint256 _weeksElapsed = (block.timestamp - bootcampStart) / 1 weeks;
    if (_weeksElapsed > weeksOfBootcamp) {
      return weeksOfBootcamp;
    }
    return _weeksElapsed;
  }

  /// @notice Pending amount to be withdrawn by the ewoler
  /// @param _ewolerId          ID for the ewoler
  function pendingEwolerExpenditure(
    uint256 _ewolerId
  ) public view virtual override returns (uint256) {
    uint256 _totalExpenditure = ewolerWeeklyExpenditure[_ewolerId] * _weeksOfBootcampElapsed();
    uint256 _totalWithdrawal = ewolerWithdrawals[_ewolerId];
    return _totalExpenditure - _totalWithdrawal;
  }

  /// @notice Withdraw an Ewoler expenditure
  /// @param _ewolerId          ID for the ewoler
  function withdrawEwolerExpenditure (
    uint256 _ewolerId
  ) public virtual override {
    uint256 _withdrawAmount = pendingEwolerExpenditure(_ewolerId);
    ewolerWithdrawals[_ewolerId] += _withdrawAmount;
    totalExpendituresWithdrawn += _withdrawAmount;
    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(currencyToken), ewolerAddress[_ewolerId], _withdrawAmount);
  }

  /// @notice Pending amount to be withdrawn by the staffer
  /// @param _stafferId         ID for the staffer
  function pendingStafferExpenditure (
    uint256 _stafferId
  ) public view virtual override returns (uint256) {
    uint256 _totalExpenditure = stafferWeeklyExpenditure[_stafferId] * _weeksOfBootcampElapsed();
    uint256 _totalWithdrawal = stafferWithdrawals[_stafferId];
    return _totalExpenditure - _totalWithdrawal;
  }

  /// @notice Withdraw an Ewol Staff Member expenditure
  /// @param _stafferId         ID for the staffer
  function withdrawStaffExpenditure (
    uint256 _stafferId
  ) public virtual override {
    uint256 _withdrawAmount = pendingStafferExpenditure(_stafferId);
    stafferWithdrawals[_stafferId] += _withdrawAmount;
    totalExpendituresWithdrawn += _withdrawAmount;
    SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(currencyToken), stafferAddress[_stafferId], _withdrawAmount);
  }

  /// @notice Pending amount pending withdrawal by staffers or ewolers
  function _pendingTotalExpenditure () private view returns (uint256) {
    uint256 _totalExpenditure = totalWeeklyExpenditure * _weeksOfBootcampElapsed();
    return _totalExpenditure - totalExpendituresWithdrawn;
  }

  /// @notice Finish the Bootcamp period
  function finishBootcamp () public virtual override onlyOwner onlyPeriod(Period.Bootcamp) {
    require(_weeksOfBootcampElapsed() == weeksOfBootcamp, "Bootcamp hasn't been completed");
    currentPeriod = Period.Repayment;
  }

  /// @notice Get Ewoler debt amount
  /// @param _ewolerId          ID for the ewoler
  /// @return Amount of ewoler debt denominated in currency tokens
  function ewolerDebt (
    uint256 _ewolerId
  ) public view virtual override returns (uint256) {
    return targetEwolers; // TO REPLACE
    
  }

  /// @notice Repay the ewoler debt
  /// @param _ewolerId      ID for the ewoler
  /// @param _amount        Amount to deposit of the `_depositToken`
  function repayDebt (
    uint256 _ewolerId,
    uint256 _amount
  ) public virtual override {
    
    
  }

  /// @notice Withdraw repayment amount
  /// @dev Amount to withdraw is proportional to campaign tokens holding
  /// @param _claimer Address of the campaign token holder withdrawing a repayment
  function withdrawRepayment (
    address _claimer
  ) public virtual override {
    
    
  }
}