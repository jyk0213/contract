pragma solidity ^0.5.1;


// 多人管理账户
contract Split{
    mapping(address=>bool) private user; // 账户信息
    mapping(address=>bool) private vote; // 分钱投票

    address payable jinrong = address(0xB40514D329Dcd8c8639102eee16941897a302341);
    address payable xuebao = address(0x45C7E4cd177176Bd016373724e2Ad3C3F26E70c3);
    address payable zhangzong = address(0xeF29CdA52B6B3F5C72DB3DECad9a8132B98Be85C);
    address payable mianao = address(0xbe9baC46B35c5B6193811F1097cBcD13EbB61e36);
    address payable liugong = address(0xC8D8eDf56E05F62E84590535e1E1c4a77CfCf4c8);
    // 修饰器(限制器)
    modifier isMember()
    {
        require(auth() == true);
        _;
    }

    event onProfit(
        uint256 value ,
        uint256 time
    );

    // 构造函数，合约被创建时,执行且只执行一次
    constructor ()
        public
    {
        user[jinrong] = true;
        user[xuebao] = true;
        user[zhangzong] = true;
        user[mianao] = true;
        user[liugong] = true;
    }

    // 没有名字的函数,在合约里只有一个.fallback函数.
    function ()
        external
        payable
    {

    }

    // 投票分账
    function handup()
        isMember()
        public
    {
        if(vote[msg.sender]==false) {
            vote[msg.sender] = true;
        }

        if(vote[jinrong] == true &&
            vote[xuebao] == true &&
            vote[zhangzong] == true &&
            vote[mianao] == true
        ) {
            vote[jinrong] = false;
            vote[xuebao] = false;
            vote[zhangzong] = false;
            vote[mianao] = false;

            // 分账
            uint256 amount = address(this).balance/5;

            jinrong.transfer(amount);
            xuebao.transfer(amount);
            zhangzong.transfer(amount);
            mianao.transfer(amount);
            liugong.transfer(amount);

            emit onProfit(amount , now);
        }


    }

    // 查询是否可以投票
    function auth()
        public
        view
        returns(bool)
    {
        return (user[msg.sender]==true) && (vote[msg.sender]==false);
    }

    //query members vaote result
    function query(address addr)
        public
        view
        returns(bool)
    {
        return vote[addr];
    }
}
