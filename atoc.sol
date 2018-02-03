pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/token/ERC827/ERC827Token.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";


contract TimeLockedable is Ownable{
    using SafeMath for uint256;

    struct TimeLockedDetail {
        uint256 endTime;
        uint256 amount;
    }

    mapping(address=>uint256)  internal timeLockedTokens;
    mapping(address=>TimeLockedDetail[]) internal timeLockedDetails;

    bool public lockFlag = false;
    bool public autoUnlockFlag = false;
    bool public showBalanceHasLockedFlag = true;

    function checkLock(address reqSender) internal{
        if(timeLockedTokens[reqSender] > 0){ //fixed
            TimeLockedDetail[] storage timeLockedDetailArr = timeLockedDetails[reqSender];
            for(uint i=0; i<timeLockedDetailArr.length; i++){
                if(timeLockedDetailArr[i].amount > 0 && now >= timeLockedDetailArr[i].endTime){
                    if(timeLockedTokens[reqSender] >= timeLockedDetailArr[i].amount){
                        timeLockedTokens[reqSender] = timeLockedTokens[reqSender].sub(timeLockedDetailArr[i].amount);
                    }else{
                        timeLockedTokens[reqSender] = 0;
                    }
                    timeLockedDetailArr[i].amount = 0;
                }
            }
        }
    }

    function addLock(address target, uint256 endTime, uint256 lockToken) onlyOwner public{
        timeLockedDetails[target].push(TimeLockedDetail({endTime: endTime, amount: lockToken}));
        timeLockedTokens[target] = timeLockedTokens[target].add(lockToken);
    }

    function unlock(address[] targets) onlyOwner public{
        for (uint j=0; j < targets.length; j++){
            if(targets[j] != address(0)) {
                TimeLockedDetail[] storage timeLockedDetailArr = timeLockedDetails[targets[j]];
                for(uint i=0; i<timeLockedDetailArr.length; i++){
                    if(timeLockedDetailArr[i].amount > 0){
                        if(timeLockedTokens[targets[j]] >= timeLockedDetailArr[i].amount){
                            timeLockedTokens[targets[j]] = timeLockedTokens[targets[j]].sub(timeLockedDetailArr[i].amount);
                        }else{
                            timeLockedTokens[targets[j]] = 0;
                        }
                        timeLockedDetailArr[i].amount = 0;
                    }
                }
            }
        }
    }

    function unlock(address target) onlyOwner public{
        if(target != address(0)) {
            TimeLockedDetail[] storage timeLockedDetailArr = timeLockedDetails[target];
            for(uint i=0; i<timeLockedDetailArr.length; i++){
                if(timeLockedDetailArr[i].amount > 0){
                    if(timeLockedTokens[target] >= timeLockedDetailArr[i].amount){
                        timeLockedTokens[target] = timeLockedTokens[target].sub(timeLockedDetailArr[i].amount);
                    }else{
                        timeLockedTokens[target] = 0;
                    }
                    timeLockedDetailArr[i].amount = 0;
                }
            }
        }
    }

    function unlock(address[] targets, uint idx) onlyOwner public{
        for (uint j=0; j < targets.length; j++){
            if(targets[j] != address(0)) {
                TimeLockedDetail[] storage timeLockedDetailArr = timeLockedDetails[targets[j]];
                if(idx >= 0 && idx < timeLockedDetailArr.length){
                    if(timeLockedDetailArr[idx].amount > 0){
                        if(timeLockedTokens[targets[j]] >= timeLockedDetailArr[idx].amount){
                            timeLockedTokens[targets[j]] = timeLockedTokens[targets[j]].sub(timeLockedDetailArr[idx].amount);
                        }else{
                            timeLockedTokens[targets[j]] = 0;
                        }
                        timeLockedDetailArr[idx].amount = 0;
                    }
                }
            }
        }
    }

    function unlock(address target, uint idx) onlyOwner public{
        if(target != address(0)) {
            TimeLockedDetail[] storage timeLockedDetailArr = timeLockedDetails[target];
            if(idx >= 0 && idx < timeLockedDetailArr.length){
                if(timeLockedDetailArr[idx].amount > 0){
                    if(timeLockedTokens[target] >= timeLockedDetailArr[idx].amount){
                        timeLockedTokens[target] = timeLockedTokens[target].sub(timeLockedDetailArr[idx].amount);
                    }else{
                        timeLockedTokens[target] = 0;
                    }
                    timeLockedDetailArr[idx].amount = 0;
                }
            }
        }
    }

    function setLockFlag(bool _lockFlag) onlyOwner public{
        lockFlag = _lockFlag;
    }

    function setAutoUnlockFlag(bool _autoUnlockFlag) onlyOwner public{
        autoUnlockFlag = _autoUnlockFlag;
    }

    function setShowBalanceHasLockedFlag(bool _showBalanceHasLockedFlag) onlyOwner public{
        showBalanceHasLockedFlag = _showBalanceHasLockedFlag;
    }

    function lockedBalanceOf(address target) public view returns(uint256) {
        return timeLockedTokens[target];
    }
}

interface TokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public;
}

contract TimeLockToken is ERC827Token, TimeLockedable{
    using SafeMath for uint256;

    function approveAndCall(address _spender, uint256 _value, bytes _extraData) public returns(bool) {
        if (approve(_spender, _value)) {
            TokenRecipient spender = TokenRecipient(_spender);
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
        return false;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        if(showBalanceHasLockedFlag){
            return super.balanceOf(_owner);
        }else{
            if(balances[_owner] < timeLockedTokens[_owner]){
                return 0;
            }else{
                return balances[_owner].sub(timeLockedTokens[_owner]);
            }
        }
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(this));
        if (lockFlag && timeLockedTokens[msg.sender] > 0){
            if(autoUnlockFlag){
                checkLock(msg.sender);
            }
            require(balances[msg.sender].sub(timeLockedTokens[msg.sender]) >= _value);
        }

        return super.transfer(_to, _value);
    }

    function transfer(address _to, uint256 _value, bytes _data) public returns (bool) {
        require(_to != address(this));
        transfer(_to, _value);
        require(_to.call(_data));
        return true;
    }
    
    function issue(address _from, address _to, uint256 _value) public onlyOwner returns (bool) {
        require(_from != address(0));
        require(_to != address(0));
        require(balances[_from] >= _value);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        return true;
    }
}

contract CrowdSale is Ownable {
    using SafeMath for uint256;

    TimeLockToken public token;
    address public beneficiary;
//    address public tokenAddressHolder;

    uint256 public rate;
    uint256 public amountGoal;
    uint256 public amountRaised;
    uint256 public amountTokenIssued;

    uint256 public minPreLimit = 0;
    uint256 public maxPreLimit = 0;
    uint256 public maxTotalLimit = 0;

    uint public startTime;
    uint public endTime;

    //0: not lock 1: lock total, 2: lock bounds, 3: get bounds > 0 then lock all
    uint public lockType = 0;
    //0: no bounds  1: ico rate, 2: buy amount
    uint public boundsType = 0;

    struct Stage {
        uint duration;
        uint256 rate;
    }

    struct Bound {
        uint256 amount;
        uint256 rate;
    }

    Stage[] public icoStages;
    Stage[] public lockStages;
    Bound[] public bounds;

    mapping(address => uint256) public purchasers;
    address[] public purchaserList;

    bool public kcyFlag;
    mapping(address => bool) public kcyWhiteAddress;

    event TokenPurchase(address purchaser, uint value, uint buyTokens, uint bonusTokens);
    event GoalReached(uint totalAmountRaised, uint totalTokenIssued);
    event FundingWithdrawn(address beneficiaryAddress, uint value);

    modifier afterEnded {
        require(isEnded());
        _;
    }

    modifier onlyOpenTime {
        require(isStarted());
        require(!isEnded());
        _;
    }

    function CrowdSale(address beneficiaryAddr, address tokenAddr, uint256 tokenRate) public {
        require(beneficiaryAddr != address(0));
        require(tokenAddr != address(0));
        require(tokenRate > 0);

        beneficiary = beneficiaryAddr;
//        tokenAddressHolder = address(this);
        token = TimeLockToken(tokenAddr);
        rate = tokenRate;

        _initStages();
    }

    function _initStages() internal;

    function getTokenAddress() public view returns(address) {
        return token;
    }

    function isStarted() public view returns(bool) {
        return 0 < startTime && startTime <= now;
    }

    function isReachedGoal() public view returns(bool) {
        return amountRaised >= amountGoal;
    }

    function isEnded() public view returns(bool) {
        return now > endTime || isReachedGoal();
    }

    function getCurrentStage() public view returns(int) {
        int stageIdx = -1;
        uint stageEndTime = startTime;
        for(uint i = 0; i < icoStages.length; i++) {
            stageEndTime += icoStages[i].duration;
            if (now <= stageEndTime) {
                stageIdx = int(i);
                break;
            }
        }
        return stageIdx;
    }

    function getRemainingTimeInSecond() public view returns(uint) {
        if(endTime == 0)
            return 0;
        return endTime - now;
    }

    function start(uint256 fundingGoalInEther) internal onlyOwner returns (bool){
        require(!isStarted());
        require(fundingGoalInEther > 0);
        amountGoal = fundingGoalInEther * 1 ether;

        startTime = now;
        uint duration = 0;
        for(uint i = 0; i < icoStages.length; i++){
            duration += icoStages[i].duration;
        }
        endTime = startTime + duration;
        return true;
    }

    function stop() public onlyOwner returns (bool){
        require(isStarted());
        endTime = now;
        return true;
    }

    function () payable public onlyOpenTime {
        require(msg.value > 0);
        require(!kcyFlag || kcyWhiteAddress[msg.sender]);
        if(minPreLimit > 0){ //最小额度限制
            require(msg.value >= minPreLimit * 1 ether);
        }
        if(maxPreLimit > 0){ //最小额度限制
            require(msg.value <= maxPreLimit * 1 ether);
        }
        if(maxTotalLimit > 0){ //最小额度限制
            require((purchasers[msg.sender].add(msg.value)) <= maxTotalLimit * 1 ether);
        }

        uint amount = msg.value;
        var (buyTokenCount, bonusTokenCount) = _getTokenCount(amount);
        uint256 totalTokenCount = buyTokenCount.add(bonusTokenCount);

        amountRaised = amountRaised.add(amount);
        amountTokenIssued = amountTokenIssued.add(totalTokenCount);

        if(lockStages.length > 0 && lockType > 0){
            uint256 lockedToken =0;
            for(uint i = 0; i < lockStages.length; i++) {
                Stage storage stage = lockStages[i];
                if (stage.rate == 0){
                    continue;
                }
                if(lockType == 3){
                    if(bonusTokenCount > 0){
                        lockedToken =  totalTokenCount.mul(stage.rate).div(100);
                        token.addLock(msg.sender, (startTime + stage.duration), lockedToken);
                    }
                }else{
                    if (lockType == 1) {
                        lockedToken =  totalTokenCount.mul(stage.rate).div(100);
                    }else if(lockType == 2){
                        lockedToken =  bonusTokenCount.mul(stage.rate).div(100);
                    }
                    token.addLock(msg.sender, (startTime + stage.duration), lockedToken);
                }
            }
        }

//        if(tokenAddressHolder == address(this)){
            token.transfer(msg.sender, totalTokenCount);
//        }else{
//            token.issue(tokenAddressHolder, msg.sender, totalTokenCount);
//        }

        beneficiary.transfer(amount);

        purchaserList.push(msg.sender);
        purchasers[msg.sender] = purchasers[msg.sender].add(amount);

        TokenPurchase(msg.sender, amount, buyTokenCount, bonusTokenCount);
        if(isReachedGoal()){
            endTime = now;
        }
    }

    function _getTokenCount(uint256 amountInWei) internal view returns(uint256 buyTokenCount, uint256 bonusTokenCount){
        buyTokenCount = amountInWei * rate;

        if(boundsType > 0){
            if(boundsType == 1){
                int stageIdx = getCurrentStage();
                if(stageIdx >= 0 && uint(stageIdx) < icoStages.length){
                    bonusTokenCount = buyTokenCount * icoStages[uint(stageIdx)].rate / 100;
                }
            }

            if(boundsType == 2){
                if(bounds.length > 0){
                    for(uint i =0; i < bounds.length; i++){
                        Bound storage bound = bounds[i];
                        if(bound.amount > 0 && amountInWei >= bound.amount * 1 ether){
                            bonusTokenCount = buyTokenCount.mul(bound.rate).div(100);
                            return;
                        }
                    }
                }
            }
        }
    }

    function transformFree(address purchaser, uint256 amount, bool locked) public onlyOwner returns (bool){
        require(purchaser != address(0));

        amountTokenIssued = amountTokenIssued.add(amount);
//        if(tokenAddressHolder == address(this)){
            token.transfer(msg.sender, amount);
//        }else{
//            token.issue(tokenAddressHolder, msg.sender, amount);
//        }

        if(locked && lockStages.length > 0){
            uint256 lockedToken = 0;
            for(uint i = 0; i < lockStages.length; i++) {
                if(lockType > 0){
                    Stage storage stage = lockStages[i];
                    if (stage.rate == 0){
                        continue;
                    }
                    lockedToken =  amount.mul(stage.rate).div(100);
                    token.addLock(purchaser, (startTime + stage.duration), lockedToken);
                }
            }
        }

        return true;
    }

    function modifyLimit(uint256 _minPreLimit, uint256 _maxPreLimit, uint256 _maxTotalLimit) onlyOwner public returns(bool){
        minPreLimit = _minPreLimit;
        maxPreLimit = _maxPreLimit;
        maxTotalLimit = _maxTotalLimit;
        return true;
    }

    function modifyLockType(uint _lockType) onlyOwner public returns (bool){
        lockType = _lockType;
        return true;
    }

    function modifyBoundsType(uint _boundsType) onlyOwner public returns (bool){
        boundsType = _boundsType;
        return true;
    }

    function modifyKcyFlag(bool _kcyFlag) onlyOwner public returns (bool){
        kcyFlag = _kcyFlag;
        return true;
    }

    function addKcyAddress(address kcyAddress, bool flag) onlyOwner public returns (bool){
        kcyWhiteAddress[kcyAddress] = flag;
        return true;
    }

    function modifyFundingGoalInEther(uint256 fundingGoalInEther) onlyOwner public returns (bool){
        require(fundingGoalInEther > 0);
        amountGoal = fundingGoalInEther * 1 ether;
        return true;
    }

    function modifyLockStages(uint idx, uint256 _duration, uint256 _rate) onlyOwner public  returns (bool){
        if(idx >= lockStages.length){
            lockStages[idx].duration = _duration * 1 days;
            lockStages[idx].rate = _rate;
        }else{
            lockStages.push(Stage({rate: _rate, duration: _duration * 1 days}));
        }
        return true;
    }

    function modifyICOStages(uint idx, uint256 _duration, uint256 _rate) onlyOwner public  returns (bool){
        if(idx >= icoStages.length){
            icoStages.push(Stage({rate: _rate, duration: _duration * 1 days}));
        }else{
            icoStages[idx].duration = _duration * 1 days;
            icoStages[idx].rate = _rate;
        }

        uint duration = 0;
        for(uint i = 0; i < icoStages.length; i++){
            duration += icoStages[i].duration;
        }
        endTime = startTime + duration;

        return true;
    }

    function modifyBounds(uint idx, uint256 _amount, uint256 _rate) onlyOwner public  returns (bool){
        if(idx >= bounds.length){
            bounds.push(Bound({rate: _rate, amount: _amount}));
        }else{
            bounds[idx].amount = _amount;
            bounds[idx].rate = _rate;
        }
        return true;
    }

//    function modifyTokenAddressHolder(address _tokenAddressHolder) onlyOwner public returns (bool){
//        tokenAddressHolder = _tokenAddressHolder;
//        return true;
//    }

    //token相关操作
    function changeTokenOwner(address target) onlyOwner public returns (bool){
        token.transferOwnership(target);
        return true;
    }

    //归还所有ETH
    function payback() onlyOwner afterEnded public {
        for(uint i =0; i < purchaserList.length; i++){
            address purchaser = purchaserList[i];
            if(purchaser != address(0)){
                uint256 amount =  purchasers[purchaser];
                if(amount > 0){
                    purchasers[purchaser] = 0;
                    purchaser.transfer(amount);
                }
            }
        }
    }

    //修改token
    function setTokenLockFlag(bool lockFlag, bool autoUnlock, bool showBalanceIncludeLocked) onlyOwner public returns (bool){
        token.setLockFlag(lockFlag);
        token.setAutoUnlockFlag(autoUnlock);
        token.setShowBalanceHasLockedFlag(showBalanceIncludeLocked);
        return true;
    }

    function unlock(address target) onlyOwner public returns (bool){
        token.unlock(target);
        return true;
    }

    function unlock(address target, uint idx) onlyOwner public returns (bool){
        token.unlock(target, idx);
        return true;
    }

    function unlockAll() onlyOwner public returns (bool){
        token.unlock(purchaserList);
        return true;
    }

    function unlockAll(uint idx) onlyOwner public returns (bool){
        token.unlock(purchaserList, idx);
        return true;
    }
}



contract ATOCToken is TimeLockToken{
    string public name = "ATOCoin";
    string public symbol = "ATOC";
    uint256 public decimals = 18;
    uint256 public INITIAL_SUPPLY = 100000000000 * (10 ** decimals);

    function ATOCToken() public {
        totalSupply_ = INITIAL_SUPPLY;
        balances[msg.sender] = INITIAL_SUPPLY;
    }
}



contract ATOCCrowedSale is CrowdSale {
    using SafeMath for uint256;

    function ATOCCrowedSale() CrowdSale(address(0x30BdcBF3d9d93Ee9acF143C94B5DE07E8695F28C), address(0x00a8d9fa245b15bda174ad51e8d02f13539430cf31), 4000000) public {
    }

    function _initStages() internal {
        delete icoStages;
        icoStages.push(Stage({rate: 0, duration: 30 days}));

        lockType = 0;
        delete lockStages;

        boundsType = 2;
        delete bounds;
        bounds.push(Bound({amount: 500, rate: 15}));
        bounds.push(Bound({amount: 300, rate: 10}));
        bounds.push(Bound({amount: 100, rate: 5}));

        uint256 icoEth = 10000;
        start(icoEth);
    }

}


