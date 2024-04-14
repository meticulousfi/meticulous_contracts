// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IMetPlus {
    function burn(uint256 _amount) external;
    function mint(address _to, uint256 _amount) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IMet {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract StakeMET is Ownable, ReentrancyGuard {

    event Stake(uint256 amount, address owner, uint256 period, uint256 id);
    event UnStake(uint256 amount, address owner, uint256 id);

    IMet public METaddress;
    IMetPlus public METPlusAddress;
    address public treasuryAddress = 0x177f6519A523EEbb542aed20320EFF9401bC47d0;

    uint256 public defaultFee = 250;
    uint256 public totalMetStaked = 0;
    uint256 public totalInterestPaid = 0;
    uint256 public totalDefaultFee = 0;

    uint256 public day30Reward = 12;
    uint256 public day180Reward = 150;
    uint256 public day360Reward = 400;
    uint256 public day540Reward = 750;

    struct Locker {
        uint256 id;
        address owner;
        uint256 amount;
        uint256 timestamp;
        uint256 lockPeriod;
        bool isLocked;
    }

    uint256 private stakeId = 1;

    mapping(address => uint256[]) public getLockerList;
    mapping(uint256 => Locker) public getLocker;

    constructor(address metToken, address metPlusToken) Ownable(msg.sender) {
        METaddress = IMet(metToken);
        METPlusAddress = IMetPlus(metPlusToken);
    }

    function stake(uint256 _amount, uint256 _period) external nonReentrant {
        require(_period == 30 days || _period == 180 days || _period == 360 days || _period == 540 days, "Invalid Time Period");
        require(METaddress.transferFrom(msg.sender, address(this), _amount));
        uint256 currentStakeId = stakeId;
        stakeId += 1;
        Locker memory locker = Locker(currentStakeId,msg.sender,_amount,block.timestamp, _period, true);
        getLocker[currentStakeId] = locker;
        getLockerList[msg.sender].push(currentStakeId);
        require(METPlusAddress.mint(msg.sender,_amount), "MET+ Mint Failed!");
        totalMetStaked += _amount;
        emit Stake(_amount, msg.sender, _period, currentStakeId);
    }

    function unStake(uint256 _stakeId) external nonReentrant {
        Locker memory locker = getLocker[_stakeId];
        require(locker.isLocked, "Tokens not staked");
        require(locker.owner == msg.sender, "You are not the owner");
        
        require(METPlusAddress.transferFrom(msg.sender, address(this), locker.amount), "Transfer of MET+ Failed");
        METPlusAddress.burn(locker.amount);
        
        locker.isLocked = false;
        getLocker[_stakeId] = locker;
        
        if(locker.lockPeriod + locker.timestamp <= block.timestamp) {
            uint256 interestAmount = calculateInterest(locker.amount, locker.lockPeriod);
            uint256 totalAmount = locker.amount + interestAmount;
            totalInterestPaid += interestAmount;
            require(METaddress.transfer(msg.sender, totalAmount), "Unstaking Failed!");
        }
        else {
            uint256 deductedAmount = locker.amount*(1000 - defaultFee)/1000;
            totalDefaultFee += locker.amount*defaultFee/1000;
            require(METaddress.transfer(treasuryAddress, locker.amount*defaultFee/1000), "Default fee to treasury failed!");
            require(METaddress.transfer(msg.sender, deductedAmount), "Unstaking Failed!");
        }
        totalMetStaked -= locker.amount;
        emit UnStake(locker.amount, msg.sender, locker.id);
    }

    function calculateInterest(uint256 _amount, uint256 _period) public view returns(uint256){
        if(_period == 30 days){
            return _amount*day30Reward/1000;
        }
        else if(_period == 180 days){
            return _amount*day180Reward/1000;
        }
        else if(_period == 360 days){
            return _amount*day360Reward/1000;
        }
        else if(_period == 540 days){
            return _amount*day540Reward/1000;
        }
        return 0;
    }

    function updateRewards(uint256 _day30, uint256 _day180, uint256 _day360, uint256 _day540) external onlyOwner {
        day30Reward = _day30;
        day180Reward = _day180;
        day360Reward = _day360;
        day540Reward = _day540;
    }

    function updateDefaultFee(uint256 _defaultFee) external onlyOwner {
        defaultFee = _defaultFee;
    }

    function isLockPeriodOver(uint256 _stakeId) public view returns (bool) {
        Locker memory locker = getLocker[_stakeId];
        if(locker.lockPeriod + locker.timestamp <= block.timestamp) {
            return true;
        }
        return false;
    }

    function updateTreasuryAddress(address _treasury) external onlyOwner {
        treasuryAddress = _treasury;
    }

}
