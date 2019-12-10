pragma solidity ^0.5.0;

interface Team {
    function refer(address name) external view returns (address);
}

contract Miner{
    Team team = Team(address(0x692a70D2e424a56D2C6C27aA97D1a86395877b3A));

    //设置收益

    uint256 private rate = 1;
    uint256 private base = 1000;//qian千 1
    uint256 private circle = 60;//天为周期
    mapping(address=>Card) private ledger;//账户信息

    struct Card{
        uint256 balance;//具体算力 || 历史总投资
        uint256 fromtime;//存储时间 \ 购买算力 \计息时间

        uint256 chunked;//已领收益
        uint256 profit;//待领收益

        uint256[] pool; // 3 4 5;
        uint256 point;//直推数量计算团队加层
        uint256 level;// 3 6 9
        uint256[10] score; //推荐 奖励算力
        uint256[5] power; //  ketui 可退 suanli算力

    }

    event onBuy(
        address indexed customer,
        uint256 value,
        uint256 time
    );

    event onWithdraw(
        address indexed customer,
        uint256 value,
        uint256 time
    );

    event onBack(
        address indexed customer,
        uint256 _amount,
        uint256 time
    );

    function()
     payable
     external
    {

    }

    function buy()
        public
        payable
   {
        uint256 amount = msg.value;
        address customer = msg.sender;

        //判断矿池余额
        //判断可买矿机

        require(amount >= 0.3 ether);

        //前端js验证
        require(ledger[customer].balance <= 2.7 ether);
        //改变层级
        checkLevel(customer,amount,true,ledger[customer].fromtime==0);

        liquid(customer);
        ledger[customer].fromtime = now;

        setPool(customer,amount);
        setScore(customer);

        emit onBuy(customer,amount,now);

    }


    function close()
        public
    {
        address payable customer = msg.sender;
        require(status(customer) == 1);

        liquid(customer);
        if(profits(customer)>0){
          _withdraw(customer);
        }


        // 计算可退算力

        uint256 rev_amount = calcRever(customer);

        if(rev_amount == 0){
            return;
        }

        ledger[customer].balance = 0;
        ledger[customer].point = 0;
        ledger[customer].pool.length = 0;
        ledger[customer].level = 0;
        ledger[customer].score[0] = 0;
        checkLevel(customer,rev_amount,false,true);

        rev_amount = SafeMath.div(rev_amount,10);

        for(uint8 i=0;i < 5;i++){
            ledger[customer].power[i] = rev_amount;
        }
        uint256 _amount = SafeMath.mul(rev_amount,5);
        customer.transfer(_amount);

        emit onBack(customer,_amount,now);
    }

    function back()
        public
    {
        address payable customer = msg.sender;
        require(status(customer) == 2);
        require(now > SafeMath.add(ledger[customer].fromtime,30*circle));

        ledger[customer].fromtime = now;
        uint256 _amount;
        for(uint8 i=1;i<5;i++){
            if(ledger[customer].power[i]>0){
                _amount = ledger[customer].power[i];
                ledger[customer].power[i] = 0;
                customer.transfer(_amount);
                emit onBack(customer,_amount,now);
                break;
            }
        }
    }

    // 领取收益
    function withdraw()
        public
    {
        address payable customer = msg.sender;
        require(status(customer) == 1);
        _withdraw(customer);
    }

    function _withdraw(address payable customer)
        internal
    {
        uint256 _profit = profits(customer);
        require(_profit>0);
        liquid(customer);
        ledger[customer].profit = 0;

        customer.transfer(_profit);
        ledger[customer].chunked = SafeMath.add(ledger[customer].chunked,_profit);

        emit onWithdraw(customer,_profit,now);
    }

    // suanli算力 /  yiling已领 / jiangli奖励 / dailing待领 / shijain时间
    function stats(address customer)
        public
        view
        returns(uint256,uint256,uint256,uint256,uint256)
    {
        return(ledger[customer].balance,ledger[customer].chunked,ledger[customer].score[0],ledger[customer].profit + profits(customer),ledger[customer].fromtime);
    }

    // 判断挖矿状态  status  0  未激活   1 挖矿中  2  退款中   3  已完成
    function status(address customer)
        public
        view
        returns(uint256)
    {
        if(ledger[customer].balance == 0 && ledger[customer].fromtime == 0)
        {
            return 0; // wei ji huo
        }

        if(ledger[customer].balance > 0)
        {
            return 1;  // wa kuang zhong
        }

        if(ledger[customer].balance == 0 && ledger[customer].power[0] > 0)
        {
            return 2; // tui kuan zhong
        }

        if(ledger[customer].balance == 0 && ledger[customer].power[0] == 0)
        {
            return 3; // over
        }
    }

    //设置上层   地址/金额算力/open || close bool /
    function checkLevel(address customer,uint256 amount ,bool is_status,bool is_fopen)
        internal
    {
        address refer = customer;
        for(uint8 i=1;i<=9;i++)
        {
            refer = team.refer(refer);
            if(refer == address(0x00)){
                break;
            }
            if(status(refer) > 1)
            {
               continue;
            }
            //open / close check higher_up nine level status
            if(is_status == true)
            {
                // check higher_up level status
                ledger[refer].score[i] = SafeMath.add(ledger[refer].score[i],amount);
            }else{
                ledger[refer].score[i] = SafeMath.sub(ledger[refer].score[i],amount);
            }

            //if this is first buy pool,check higher_up level's point status and team'level
            if(i == 1 && is_fopen == true){
                if(is_status == true){
                    ledger[refer].point = SafeMath.add(ledger[refer].point,1);
                }else{
                    ledger[refer].point = SafeMath.sub(ledger[refer].point,1);
                }
                if(status(refer) == 1 ){
                    setLevel(refer);
                }
            }

            if(status(refer) == 0)
            {
                continue;
            }

            if(i == 1 || i<=ledger[customer].level){
                liquid(refer);
                setScore(refer);
            }

        }
    }

    //设置挖矿推荐算力及团队加成算力
    function setScore(address customer)
        internal
    {
        ledger[customer].score[0] = 0;
        for(uint8 i = 1;i<=ledger[customer].level;i++){
            if(i == 1)
            {
                ledger[customer].score[0] = ledger[customer].score[0] + ledger[customer].score[i];
            }else{
                ledger[customer].score[0] = ledger[customer].score[0] + ledger[customer].score[i]/10;
            }
        }
    }


    // 设置团队层级
    function setLevel(address customer)
        internal
    {
        if(ledger[customer].balance >= 2.7 ether)
        {
            ledger[customer].level = ledger[customer].point < 9 ? ledger[customer].point : 9;
        }
        if(ledger[customer].balance >= 0.9 ether)
        {
            ledger[customer].level = ledger[customer].point < 6 ? ledger[customer].point : 6;
        }
        if(ledger[customer].balance >= 0.3 ether)
        {
            ledger[customer].level = ledger[customer].point < 3 ? ledger[customer].point : 3;
        }
    }
    // 设置矿池
    function setPool(address customer,uint256 amount)
        internal
    {
        uint256 oldPool = calcPool(customer);
        ledger[customer].balance = SafeMath.add(ledger[customer].balance,amount);
        // sec thr four
        uint256 newPool = calcPool(customer);

        ledger[customer].pool.push(amount);

        ledger[customer].pool.push(SafeMath.sub(newPool,oldPool));


    }

    // 计算矿池大小
    function calcPool(address customer)
        internal
        view
        returns(uint256 pol)
    {
        if(ledger[customer].balance >= 2.7 ether)
        {
            return SafeMath.mul(ledger[customer].balance,5);

        }else if(ledger[customer].balance >= 0.9 ether)
        {
            return SafeMath.mul(ledger[customer].balance,4);

        }else if(ledger[customer].balance >= 0.3 ether)
        {
            return SafeMath.mul(ledger[customer].balance,3);
        }

    }

    function liquid(address customer)
        internal
        returns(uint256)
    {
        if(ledger[customer].fromtime == 0){
            return 0;
        }

        if(status(customer) !=1){
            return 0;
        }

        if(profits(customer) == 0){
            return 0;
        }

        uint256 diff = SafeMath.sub(now,ledger[customer].fromtime);
        uint256 ft = SafeMath.mod(diff,circle);
        ledger[customer].fromtime = SafeMath.sub(now,ft);
        ledger[customer].profit = SafeMath.add(ledger[customer].profit,profits(customer));


    }

    // 待领收益
    function profits(address customer)
        internal
         view
        returns(uint256)
    {
        if(status(customer) != 1){
            return 0;
        }
        if(now < ledger[customer].fromtime + circle){
            return 0;
        }

        // 计息时间
        uint256 time = SafeMath.sub(now,ledger[customer].fromtime);
        uint256 day = SafeMath.div(time,circle);

        //当前算力 +  奖励算力
        uint256 unprofit = SafeMath.mul(SafeMath.add(calcPow(customer),calcRward(customer))/base,SafeMath.mul(day,rate));

        uint256 poolimit =  calcPool(customer);
        uint256 sProfit = SafeMath.add(ledger[customer].chunked,unprofit);

        if(sProfit > poolimit){
            unprofit = SafeMath.sub(poolimit,ledger[customer].chunked);
        }

        return unprofit;
    }

    //当前算力
    function calcPow(address customer)
        internal
         view
        returns(uint256)
    {
        uint256 sum = 0;
        uint256 pow = 0;
        for(uint256 i=0;i < ledger[customer].pool.length;i+=2)
        {
            sum =sum + ledger[customer].pool[i+1];
            if(sum > ledger[customer].chunked){
                pow += ledger[customer].pool[i];
            }
        }

        return pow;
    }

    //奖励算力
    function calcRward(address customer)
        internal
        view
        returns(uint256)
    {
        if(ledger[customer].score[0] >= 2.7 ether)
        {
            return ledger[customer].score[0];
        }else if(ledger[customer].score[0] >= 0.9 ether)
        {
            return ledger[customer].score[0]*8/10;
        }else if(ledger[customer].score[0] >= 0.3 ether)
        {
            return ledger[customer].score[0]*6/10;
        }
    }

    //计算可退算力

    function calcRever(address customer)
        internal
        returns(uint256)
    {
        uint256 sum = 0;//总和
        uint256 pow = 0; //总算力成本
        uint256 rever = 0;//可退算力
        for(uint8 i=1;i<=ledger[customer].pool.length;i+=2){
            sum = sum + ledger[customer].pool[i];
            pow = pow + ledger[customer].pool[i-1];
            if(pow <= SafeMath.sub(sum,ledger[customer].chunked)){
                rever = rever + pow;
            }else{
                rever = rever + SafeMath.sub(sum,ledger[customer].chunked);
            }

        }

        return rever;
    }
}

library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
        /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}
