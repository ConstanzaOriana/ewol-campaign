// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 < 0.9.0;

import "./IEwolCampaignRegistry.sol";
import "./EwolCampaignPrototype.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/// @title Ewol Campaign Registry
/// @author heidrian.eth
/// @notice This contract is used to launch Ewol Academy Web3 Bootcamp campaigns
contract EwolCampaignRegistry is IEwolCampaignRegistry, Ownable {

  /// @notice Struct used to save the thada of a launched campaign
  struct Campaign {
    address contractAddress;
    address implementationAddress;
    uint256 timestamp;
    address launcher;
  }

  /// @notice Address of the prototype implementation used on future campaign launches
  address public prototypeAddress;

  /// @notice Array of campaings that have been launched
  Campaign[] public launchedCampaigns;

  /// @notice Event emitted when a new campaign is launched
  /// @param _campaignId         ID of the campaign
  /// @param _campaignAddress    Campaign contract address
  event CampaignLaunched (uint256 _campaignId, address _campaignAddress);

  constructor () {
    EwolCampaignPrototype campaignPrototype = new EwolCampaignPrototype();
    campaignPrototype.init("", 0, 0, address(0), 0, 0, address(this)); // Dummy initialization
    prototypeAddress = address(campaignPrototype);
  }

  /// @notice Launch a new campaign
  /// @dev 
  /// @param _campaignName        Name of the Ewol Campaign
  /// @param _targetEwolers       Target quantity of Ewolers to raise funding for
  /// @param _investmentPerEwoler Amount of currency to be raised per Ewoler
  /// @param _currencyToken       Address of the ERC20 token used as campaign currency
  /// @param _weeksOfBootcamp     Number of weeks of the bootcamp
  /// @param _premintAmount       Amount of campaign tokens preminted for the campaign launcher
  function launchCampaign (
    string calldata _campaignName,
    uint16 _targetEwolers,
    uint256 _investmentPerEwoler,
    address _currencyToken,
    uint8 _weeksOfBootcamp,
    uint256 _premintAmount
  ) public override onlyOwner {
    EwolCampaignPrototype newCampaignContract = EwolCampaignPrototype(Clones.clone(prototypeAddress));
    newCampaignContract.init(
      _campaignName,
      _targetEwolers,
      _investmentPerEwoler,
      _currencyToken,
      _weeksOfBootcamp,
      _premintAmount,
      msg.sender
    );
    Campaign memory launchedCampaign = Campaign(
      address(newCampaignContract),
      prototypeAddress,
      block.timestamp,
      msg.sender
    );
    uint256 _campaignId = launchedCampaigns.length;
    launchedCampaigns.push(launchedCampaign);
    emit CampaignLaunched(_campaignId, address(newCampaignContract));
  }

  /// @notice Update the protype contract address to be cloned on launch
  /// @param _implementation      Prototype contract address
  function updateCampaignPrototype (address _implementation) public override onlyOwner {
    prototypeAddress = _implementation;
  }
}