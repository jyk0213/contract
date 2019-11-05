pragma solidity  ^0.5.1;

contract Lock {
    uint256 private base = 1000;
    uint256 private rate = 1;
    uint256 active = 1;
    uint256 private circle = 86400; // 24小时
    mapping(address=>card) private user; //
    address  admin = address(0x49af2ff0665aC7CD9A067ca995BA2Ce278fB49D4);

    struct card {
        uint256 balance;
        uint256 total;
        uint256 already;
        uint256 nexttime;
    }

    modifier isAdmin() {
        require(msg.sender == admin);
        _;
    }

    function change()
        isAdmin()
        public
        returns(uint256)
    {
        if(active == 1){
            active = 0;
        }else{
            active = 1;
        }
        return (active);
    }

    modifier isEsment()
    {
        address customer = msg.sender;
        uint256 time = SafeMath.sub(now,user[customer].nexttime);
        require(time > 0 && active == 1);
        _;
    }

    event onDeposit(
        address indexed customer,
        uint256 value,
        uint256 fromtime
    );
    event onWithdraw(
        address indexed customer,
        uint256 value,
        uint256 fromtime
    );
    function()
     external
     payable
    {
        address customer = msg.sender;
        uint256 value = msg.value;
        require(value > 0);

        user[customer].nexttime = SafeMath.add(now,circle);
        user[customer].balance = SafeMath.add(user[customer].balance,value);
        user[customer].total  = user[customer].total + value;
        emit onDeposit(customer,value,now);
    }

    function withdraw()
        isEsment()
        public
    {

        address payable customer = msg.sender;
        uint256 amount = calc(customer);
        require(amount> 0);
        if(user[customer].balance == 0)
        {
            return;
        }
        user[customer].nexttime = SafeMath.add(now,circle);

        user[customer].balance = SafeMath.sub(user[customer].balance,amount);
        user[customer].already += amount;

        customer.transfer(amount);

        emit onWithdraw(customer,amount,now);
    }

    function stats(address customer)
        public
        view
        returns(uint256,uint256,uint256,uint256,uint256)
    {
        return (user[customer].total,user[customer].already,user[customer].balance,user[customer].nexttime,active);
    }

    function calc(address customer)
        internal
        view
        returns(uint256)
    {
        if(user[customer].balance == 0)
        {
            return 0;
        }

        return (SafeMath.div(user[customer].balance*rate,base));
    }

}


library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.  乘法
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
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.除法
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
