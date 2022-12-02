const { expect } = require("chai");
const hre = require("hardhat");

const registryContractName = "EwolCampaignRegistry";
let registryInstance;
let registryAddress;

let prototypeAddress;

let stablecoinInstance;
let stablecoinAddress;

let campaignId;
let campaignAddress;
let campaignInstance;

const sigInstances = {};
const sigAddrs = {};
const signerRoles = ["deployer", "nonOwner", "ewoler", "staff", "investor", "secondInvestor",];

describe("EwolCampaign", function () {
  describe("EwolCampaignRegistry", function () {
    it("Should initialize signers", async function () {
      const testSigners = await hre.ethers.getSigners();
      for (let iSigner = 0; iSigner < signerRoles.length; iSigner++) {
        const signerRole = signerRoles[iSigner];
        sigInstances[signerRole] = testSigners[iSigner];
        sigAddrs[signerRole] = await sigInstances[signerRole].getAddress();
      }
    });

    it("Should deploy the stablecoin contract", async function () {
      const stablecoinFactory = await hre.ethers.getContractFactory(
        "EwolStablecoin",
        sigInstances.deployer
      );
      stablecoinInstance = await stablecoinFactory.deploy(0);
      stablecoinAddress = await stablecoinInstance.address;
      await stablecoinInstance.deployed();

      const stablecoinSupply = await stablecoinInstance.totalSupply();
      expect(stablecoinSupply).to.equal(0);

      const stablecoinOwner = await stablecoinInstance.owner();
      expect(stablecoinOwner).to.equal(sigAddrs.deployer);
    });

    it("Should mint stablecoins for each role", async function () {
      for (let iSigner = 0; iSigner < signerRoles.length; iSigner++) {
        const signerRole = signerRoles[iSigner];
        const mintingTx = await stablecoinInstance.mintTokens(
          sigAddrs[signerRole],
          hre.ethers.utils.parseUnits("1000000.0", 18)
        );
        await mintingTx.wait();
      }
    });

    it("Should deploy the Registry contract which deploys an initial prototype", async function () {
      const registryFactory = await hre.ethers.getContractFactory(
        registryContractName,
        sigInstances.deployer
      );
      registryInstance = await registryFactory.deploy();

      await registryInstance.deployed();

      registryAddress = registryInstance.address;
      console.log("Registry contract deployed to:", registryAddress);
    });

    it("Should provide the initial prototype address", async function () {
      prototypeAddress = await registryInstance.prototypeAddress();

      console.log("Initial prototype contract deployed to:", prototypeAddress);

      expect(prototypeAddress).to.be.a.properAddress;
      expect(prototypeAddress).to.not.equal(hre.ethers.constants.AddressZero);
    });

    it("Should assign the Registry owner role to the contract deployer", async function () {
      const registryOwnerAddr = await registryInstance.owner();

      expect(registryOwnerAddr).to.equal(sigAddrs.deployer);
    });

    it("Should enable the owner to launch a new campaign", async function () {
      const campaignName = "EWOL Cohorte 1";
      const targetEwolers = 25;
      const investmentPerEwoler = hre.ethers.utils.parseUnits("2000.0", 18);
      const weeksOfBootcamp = 10;
      const premintAmount = hre.ethers.utils.parseUnits("5000.0", 18);

      const launchTx = await registryInstance.launchCampaign(
        campaignName,
        targetEwolers,
        investmentPerEwoler,
        stablecoinAddress,
        weeksOfBootcamp,
        premintAmount
      );
      const launchTxReceipt = await launchTx.wait();

      const campaignLaunchedEvent = launchTxReceipt.events.find(
        (event) => event.event === "CampaignLaunched"
      );
      [campaignId, campaignAddress] = campaignLaunchedEvent.args;

      expect(campaignId).to.equal(0);
      expect(campaignAddress).to.be.a.properAddress;
      expect(campaignAddress).to.not.equal(hre.ethers.constants.AddressZero);

      const campaignFactory = await hre.ethers.getContractFactory(
        "EwolCampaignPrototype",
        sigInstances.deployer
      );
      campaignInstance = campaignFactory.attach(campaignAddress);

      expect(await campaignInstance.name()).to.equal(campaignName);
      expect(await campaignInstance.targetEwolers()).to.equal(targetEwolers);
      expect(await campaignInstance.investmentPerEwoler()).to.equal(
        investmentPerEwoler
      );
      expect(await campaignInstance.currencyToken()).to.equal(
        stablecoinAddress
      );
      expect(await campaignInstance.weeksOfBootcamp()).to.equal(
        weeksOfBootcamp
      );

      expect(await campaignInstance.totalSupply()).to.equal(premintAmount);
      expect(await campaignInstance.balanceOf(sigAddrs.deployer)).to.equal(
        premintAmount
      );

      expect(await campaignInstance.owner()).to.equal(sigAddrs.deployer);

      expect(await campaignInstance.investmentCap()).to.equal(
        investmentPerEwoler.mul(targetEwolers)
      );
    });

    it("Should prevent a non owner from launching a new campaign", async function () {
      const registryInstanceForNonOwner = registryInstance.connect(
        sigInstances.nonOwner
      );
      const failedLaunchTxNonOwner = registryInstanceForNonOwner.launchCampaign(
        "",
        0,
        0,
        stablecoinAddress,
        0,
        0
      );

      expect(failedLaunchTxNonOwner).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });
    it("Should allow to enrol an ewoler", async function () {
      const createEwolerTx = await campaignInstance.enrollEwoler(
        0,
        sigAddrs.ewoler,
        hre.ethers.utils.parseUnits("75.0", 18)
      );
      createEwolerTx.wait();
      expect(await campaignInstance.ewolerAddress(0)).to.not.equal(
        hre.ethers.constants.AddressZero
      );
      expect(await campaignInstance.ewolerWeeklyExpenditure(0)).to.not.equal(0);
    });
    it("Should prevent a non owner from create a new ewoler", async function () {
      const campaignInstanceForNonOwner = campaignInstance.connect(
        sigInstances.nonOwner
      );
      const failedEnrollTxNonOwner = campaignInstanceForNonOwner.enrollEwoler(
        1,
        sigAddrs.ewoler,
        hre.ethers.utils.parseUnits("75.0", 18)
      );
      expect(failedEnrollTxNonOwner).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });
    it("Should prevent to enroll an ewoler that already exist", async function () {
      const createEwolerTx = campaignInstance.enrollEwoler(
        0,
        sigAddrs.ewoler,
        hre.ethers.utils.parseUnits("75.0", 18)
      );

      expect(createEwolerTx).to.be.revertedWith("Ewoler already enrolled");
    });
    it("Should allow to enroll a staff-member", async function () {
      const enrollStaffTx = await campaignInstance.enrollStaff(
        0,
        sigAddrs.staff,
        hre.ethers.utils.parseUnits("75.0", 18),
        hre.ethers.utils.parseUnits("50.0", 18)
      );
      enrollStaffTx.wait();
      expect(await campaignInstance.stafferAddress(0)).to.not.equal(
        hre.ethers.constants.AddressZero
      );
      expect(await campaignInstance.stafferWeeklyExpenditure(0)).to.not.equal(
        0
      );
    });
    it("Should prevent a non owner from create a new staff-member", async function () {
      const campaignInstanceForNonOwner = campaignInstance.connect(
        sigInstances.nonOwner
      );
      const failedEnrollStaffTxNonOwner =
        campaignInstanceForNonOwner.enrollStaff(
          1,
          sigAddrs.ewoler,
          hre.ethers.utils.parseUnits("75.0", 18),
          hre.ethers.utils.parseUnits("50.0", 18)
        );
      expect(failedEnrollStaffTxNonOwner).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });
    it("Should prevent to enroll a staff-member that already exists", async function () {
      const enrollStaffTx = campaignInstance.enrollStaff(
        0,
        sigAddrs.ewoler,
        hre.ethers.utils.parseUnits("75.0", 18),
        hre.ethers.utils.parseUnits("50.0", 18)
      );

      expect(enrollStaffTx).to.be.revertedWith("Ewoler already enrolled");
      expect();
    });
    it("Should allow to deposit investment", async function () {
      const firstInvestorInstance = await campaignInstance.connect(
        sigInstances.investor
      );
      const investorStablecoinInstance = await stablecoinInstance.connect(
        sigInstances.investor
      );
      const approveToSpend = await investorStablecoinInstance.approve(
        campaignAddress,
        hre.ethers.utils.parseUnits("2000.0", 18)
      );
      await approveToSpend.wait();
      const investmentTx = await firstInvestorInstance.depositInvestment(
        stablecoinAddress,
        hre.ethers.utils.parseUnits("2000.0", 18)
      );
      await investmentTx.wait();

      const totalInvestedOnCampaign = await campaignInstance.totalInvested();
      expect(totalInvestedOnCampaign).to.equal(
        hre.ethers.utils.parseUnits("2000.0", 18)
      );
      it("Should allow to deposit investment only on Investment period ", async function () {
        const changeOfPeriod = await campaignInstance.startBootcamp();
        const firstInvestorInstance = await campaignInstance.connect(
          sigInstances.investor
        );
        const investorStablecoinInstance = await stablecoinInstance.connect(
          sigInstances.investor
        );
        const approveToSpend = await investorStablecoinInstance.approve(
          campaignAddress,
          hre.ethers.utils.parseUnits("2000.0", 18)
        );
        await approveToSpend.wait();
        const investmentTx = firstInvestorInstance.depositInvestment(
          stablecoinAddress,
          hre.ethers.utils.parseUnits("2000.0", 18)
        );
        expect(investmentTx).to.be.revertedWith(
          "Method not available at the moment"
        );
      });

      it("Should allow to deposit no more than investCap ", async function () {
        const secondInvestorInstance = await campaignInstance.connect(
          sigInstances.secondInvestor
        );
        const secondInvestorStablecoinInstance =
          await stablecoinInstance.connect(sigInstances.secondInvestor);
        const approveToSpend = await secondInvestorStablecoinInstance.approve(
          campaignAddress,
          hre.ethers.utils.parseUnits("200000.0", 18)
        );
        await approveToSpend.wait();
        const investmentTx = secondInvestorInstance.depositInvestment(
          stablecoinAddress,
          hre.ethers.utils.parseUnits("200000.0", 18)
        );
        expect(investmentTx).to.be.revertedWith(
          "Deposit exceeds investment cap"
        );
      });
      it("Should deposit no more than investCap ", async function () {
        await setCurrencyToken(stablecoinAddress);
        const secondInvestorInstance = await campaignInstance.connect(
          sigInstances.secondInvestor
        );
        const secondInvestorStablecoinInstance =
          await stablecoinInstance.connect(sigInstances.secondInvestor);
        const approveToSpend = await secondInvestorStablecoinInstance.approve(
          campaignAddress,
          hre.ethers.utils.parseUnits("200.0", 18)
        );
        await approveToSpend.wait();
        const investmentTx = secondInvestorInstance.depositInvestment(
          stablecoinAddress,
          hre.ethers.utils.parseUnits("200.0", 18)
        );
        expect(investmentTx).to.be.revertedWith("Deposit token not supported");
      });
    });
  });
});
