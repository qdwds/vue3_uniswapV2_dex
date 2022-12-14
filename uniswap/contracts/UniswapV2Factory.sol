//SPDX-License-Identifier: MIT
pragma solidity =0.5.16;
import "hardhat/console.sol";
interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IUniswapV2ERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

// ???????????????????????????????????????????????????????????????????????????????????????????????????
// ?????????????????????
interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

// ?????????????????????
contract UniswapV2ERC20 is IUniswapV2ERC20 {
    using SafeMath for uint;

    string public constant name = "Uniswap V2";
    string public constant symbol = "UNI-V2";
    uint8 public constant decimals = 18;
    uint  public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    // ???????????????Dapp???????????????????????????????????????????????????????????????????????????????????????????????????Dapp
    bytes32 public DOMAIN_SEPARATOR;

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    // ???????????????????????????????????????permit??????????????????????????????????????????????????????????????????
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // ????????????????????????????????????????????????????????????
    mapping(address => uint) public nonces;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    constructor() public {
        uint chainId;
        assembly {
            chainId := chainid
        }
        // eip712 ?????? ????????????
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                // ?????????????????????salt???DOMAIN_SEPARATOR?????????????????????????????????
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)), //  ????????????
                keccak256(bytes("1")),  //  ??????
                chainId,                //  ????????????ID
                address(this)           //  ?????????????????????
            )
        );
    }

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    // ???????????????????????????????????????????????????
    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    // ????????????????????????
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, "UniswapV2: EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        // ??????
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, "UniswapV2: INVALID_SIGNATURE");
        _approve(owner, spender, value);
    }
}

// ????????????
// ?????????????????????
contract UniswapV2Pair is IUniswapV2Pair, UniswapV2ERC20 {
    using SafeMath  for uint;
    // ????????????uint224?????????solidity?????????????????????????????????token??????????????????????????????shiyong UQ112*112????????????????????????
    using UQ112x112 for uint224;

    // ??????????????? ??????1000????????????????????????????????????????????????
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    // transfor bytecode ????????????call??????token???transfer??????
    // ?????????????????????call?????? ????????????????????????transfer?????????
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    // ?????????????????????pair??????????????????????????????????????????????????????????????????????????????????????????
    address public factory; //  ???=??????????????????
    address public token0;  //  token0??????
    address public token1;  //  token1??????
    
    // ??????pair??????????????????token?????????
    // ?????????????????????( k = x * y )???????????????????????????????????????????????????????????????
    // reserve0 + reserve1 + blockTimestampLast == uint?????????
    // ????????????token0 ??? token1 ?????????
    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    // ????????????????????????????????????????????????
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    // ??????????????????????????????????????????
    // ??????unistap v2 ?????????????????????????????????????????????????????????????????????????????????????????????
    uint public price0CumulativeLast;
    uint public price1CumulativeLast;

    // ??????????????????????????????????????????????????????????????????????????????
    // reserve0 * reserve1, ????????????????????????????????????????????????
    // ?????????????????????????????????????????????????????????0.??????????????????????????????????????????????????????k??????????????????????????????????????????k????????????????????????????????????????????????
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    // ??????????????????????????????????????????
    uint private unlocked = 1;
    // ??????????????????unlocked == 1????????????????????????
    // ????????????????????????????????????unlocked = 0?????????????????????????????????
    // ??????????????? unlocked = 1?????????????????????
    modifier lock() {
        require(unlocked == 1, "UniswapV2: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // ??????token0???token1?????????????????????????????????????????????
    // ??????????????????????????????????????????????????????????????????
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
        console.log("_reserve0", _reserve0 );
        console.log("_reserve1", _reserve1);
        console.log("_blockTimestampLast", _blockTimestampLast);
        console.log("getReserves",_reserve0 + _reserve1 + _blockTimestampLast);
    }

    /*
    * @dev ??????????????????
    * @param token token??????
    * @param to to??????
    * @param value ??????
    */
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        // ???????????????????????????????????????????????????????????????true
        console.log("success", success);
        // console.log("data", data);
        console.log("data.length", data.length);
        console.log("abi.decode(data, (bool))", abi.decode(data, (bool)));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "UniswapV2: TRANSFER_FAILED");
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );  
    // ????????????
    event Sync(uint112 reserve0, uint112 reserve1);
    
    constructor() public {
        factory = msg.sender;
    }

    //  ?????????????????????????????????
    //  ???UNiswapV2Factory.sol?????? createPair ??????????????? ???????????????token????????????
    function initialize(address _token0, address _token1) external {
        // ????????????????????????
        require(msg.sender == factory, "UniswapV2: FORBIDDEN"); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    // ????????????????????????
    /*
    * @dev ????????????????????????????????????????????????????????????????????????????????????
    * @param balance0 ??????0
    * @param balance1 ??????1
    * @param _reserve0 ?????????0
    * @param _reserve1 ?????????1
    * update reserves and, on the first call per block, price accumulators
    */
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        // ????????????0?????????1 ?????? uint112????????????
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), "UniswapV2: OVERFLOW");
        // ???????????????????????????????????????uint32
        // ???????????????token????????????112?????????  256 - 112 -112  = 34??????????????????34?????????32??????????????????????????????
        // ???????????????32???
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        console.log("block.timestamp", block.timestamp);
        console.log("block.timestamp % 2**32", block.timestamp % 2**32);
        console.log("blockTimestamp", blockTimestamp);

        // ??????????????????
        // ?????????????????????????????? timeElapsed ????????? 0
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        // 112 + 112 + 32 = 256
        // ????????????????????????????????????256?????????112?????????????????????112?????????????????????32??????????????????
        // ?????????????????? > 0??????????????????0????????????1 !== 0???????????????????????????
        // ????????????????????????????????????????????????timeElapsed?????????????????????==0 ??? ?????????????????????????????????????????????????????????????????????????????????????????????????????????
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            // ??????0???????????? += ?????????1 * 2 ** 112 / ?????????0 * ????????????
            // ?????????????????????
            // ??????224??? _reserve0 ???????????? _reserve1 
            console.log("uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0))",uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)));
            console.log("uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed", uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed);
            console.log("timeElapsed", timeElapsed);
            // UQ112 ?????? 224???  256 = 224 * 32?????????32????????? * 224 ?????????  < 256 ???????????????????????????????????????????????????
            // ????????????????????????????????????
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            console.log("price0CumulativeLast", price0CumulativeLast);
            console.log("price1CumulativeLast", price1CumulativeLast);
        }

        // ????????????????????????
        // ??????0?????????1 ?????? ?????????0????????????1 ???
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);

        // ?????????????????????
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    // ???????????????
    // ?????????????????????????????????????????? sqrt(k) ????????? 1/6
    // ??????????????????????????????????????????k????????????????????????????????????????????????????????????k?????????????????????????????????????????????
    /*
    * @dev ???????????????????????????????????????1/6?????????sqrt(k)
    * @param _reserve0 ?????????0
    * @param _reserve1 ?????????1
    * @return feeOn
    * ?????????????????????????????????????????????????????
    * if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    */
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        // ?????????????????????feeTo?????????
        address feeTo = IUniswapV2Factory(factory).feeTo();
        console.log("_mintFee ??????", feeTo);
        // ??????feeTo != 0????????????feeOn?????? true ?????? false
        // feeOn = teeTo != address(0) ? treu :false;
        feeOn = feeTo != address(0);
        console.log("_mintFee feeOn",feeOn);
        // ??????k???
        uint _kLast = kLast; // gas savings
        // ??????feeOn??????true
        if (feeOn) {
            // k ????????? 0
            if (_kLast != 0) {
                // ?????????_reserve0*_reserve1???????????????
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                // ??????k???????????????
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    // ?????? = erc20?????? * (rootK - rootKlast)
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    // ?????? = rootK * 5 + rootKLast
                    uint denominator = rootK.mul(5).add(rootKLast);
                    // ????????? = ?????? / ??????
                    uint liquidity = numerator / denominator;
                    // ????????? > 0 ?????????????????????feeTo?????? UniswapV2ERC20???_mint ??????
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    //  ????????????????????????????????????????????????ERC20???LP??????????????????
    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint liquidity) {
        // ????????????token???????????????
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        // ??????token???????????????????????????, ?????????????????????(?????????????????????????????? token0 == btc token1 == usdt),????????????????????????token????????????????????????
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        // ????????????????????? ?????????????????? ??????
        // amount0 = ??????0 - ??????0
        uint amount0 = balance0.sub(_reserve0);
        // amount1 = ??????1 - ??????1
        uint amount1 = balance1.sub(_reserve1);
        // ????????????????????? ????????????????????????????????????
        bool feeOn = _mintFee(_reserve0, _reserve1);
        console.log("feeOn", feeOn);
        // ?????????????????????????????????
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        // ??????????????????????????????0
        if (_totalSupply == 0) {
            // ?????????????????????????????????????????????????????? ??????k - MINIMUM_LIQUIDITY?????????????????????
            // ????????? = (??????0 * ??????1)???????????? - ???????????????1000
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            console.log("main liquidity", liquidity);
            // ??? MINIMUM_LIQUIDITY ???????????????0???????????????
            // ????????????0?????????????????????????????????????????????
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            // ???????????????token????????????????????????????????????????????????
            // ????????? = ?????????(amount0 * _totalSupply - _reserve0 ??? (amount1 * _totalSupply) / reserve1)
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        // ?????????????????????0?????????????????? ?????????????????????
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        // ??????????????????to?????????????????????????????????????????????
        _mint(to, liquidity);
        //  ???????????????
        _update(balance0, balance1, _reserve0, _reserve1);
        // ?????????????????? ??? k = ??????0 * ??????1
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // ??????????????????/???????????????
    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        console.log("burn _reserve0 _reserve1",_reserve0, _reserve1);

        // ??????token0???token1????????????????????? => ??????gas
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings

        // ?????????????????????token0???otken1?????????
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));

        // ?????????????????????balanceOf????????????????????????????????????????????????
        // ???????????????????????????????????????????????????pair????????????????????????
        uint liquidity = balanceOf[address(this)];

        // ???????????????
        bool feeOn = _mintFee(_reserve0, _reserve1);
        // ?????????????????????????????????
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        // amount0???amount1????????????????????????????????????
        // amount0 = ??????????????? * ??????0 / totalSuopply ??????????????????????????????
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        
        // ???????????????????????????????????????0
        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED");
        
        // ?????????????????????
        _burn(address(this), liquidity);
        // ???amount0?????????token0?????????to??????
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        // ????????????token?????????
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }
    /*
    * @dev ????????????
    * @param amount0Out ??????token0????????????
    * @param amount1Out ??????token1????????????
    * @param to to??????
    * @param data ?????????????????????
    * @notice ??????????????????????????????????????????????????????????????????
    * this low-level function should be called from a contract which performs important safety checks
    */
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        // ????????????????????????0
        require(amount0Out > 0 || amount1Out > 0, "UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
        // ???????????????token0???token1??????????????????????????????
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        // ??????token?????? ????????????????????????????????????
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "UniswapV2: INSUFFICIENT_LIQUIDITY");

        // ???????????????????????????token?????????
        uint balance0;
        uint balance1;
        // ????????????
        {
            // scope for _token{0,1}, avoids stack too deep errors
            // ??????_token{ 0, 1 }????????????????????????????????????EVM????????????16??????
            // ??????????????????????????????token??????????????????gas
            address _token0 = token0;
            address _token1 = token1;
            // ??????token0???token1 !== to
            require(to != _token0 && to != _token1, "UniswapV2: INVALID_TO");
            //  ??????token0??????,???token0?????????
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            // ??????data????????????0?????????to???????????????
            // ?????????   ?????????????????? ??????????????????
            if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
            // ??????token0???token1??????????????????????????????????????????????????????????????????
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
            console.log("swap balance0",balance0);
            console.log("swap balance1",balance1);
        }
        /**
            if(???????????? > ????????????0 - ??????????????????){
                return ???????????? - ??? ???????????????0 - ?????????????????? ???
            }else{
                return 0 
            }
         */
        // ???????????????????????????????????????
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        
        // ?????? ?????? (amount0In || amount1In)  > 0
        // ?????????????????????token??????????????????0 ??????????????????????????????
        require(amount0In > 0 || amount1In > 0, "UniswapV2: INSUFFICIENT_INPUT_AMOUNT");
        // ??????????????????
        { 
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            // ?????????????????? =  ???????????? * 1000 - (amount0In * 3)
            // ??????????????????????????????
            uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
            uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
            // ?????????????????????0 * ???????????????1 >= ??????0 * ??????1 * 1000000
            console.log("balance0Adjusted.mul(balance1Adjusted)", balance0Adjusted.mul(balance1Adjusted));
            console.log("uint(_reserve0).mul(_reserve1).mul(1000**2)", uint(_reserve0).mul(_reserve1).mul(1000**2));
            // ?????????????????? ????????? ????????????????????????
            // ?????????????????????????????????????????????
            // ????????????????????????????????????????????????????????????????????????????????????
            require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), "UniswapV2: K");
        }
        // ???????????????
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    

    /*
    * @dev ?????????????????????????????????????????????????????????
    * ??????????????? == ??????????????????????????????????????????????????????????????????????????????`address(to`??????????????????????????????
    * ???????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
    * ????????? ???????????????????????????????????????????????????????????????????????????????????????????????????
    * @param to to?????? 
    */
    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        console.log("IERC20(_token0).balanceOf(address(this)).sub(reserve0)", IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        console.log("IERC20(_token1).balanceOf(address(this)).sub(reserve1)", IERC20(_token1).balanceOf(address(this)).sub(reserve1));
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    

    /*
    * @dev ?????????????????????????????? == ????????????????????????????????????????????????????????????
    */
    // force reserves to match balances
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}

// ????????????
contract UniswapV2Factory is IUniswapV2Factory {
    // ???????????????????????? ??????????????????????????????????????????????????? 000000
    address public feeTo;
    // ??????????????????????????????????????????
    address public feeToSetter;
    // ???????????????????????????
    mapping(address => mapping(address => address)) public getPair;
    // {
    //     address:{
    //         address:address
    //     }
    // }
    // ???????????????????????????  ?????????????????????
    address[] public allPairs;
    // ??????????????????????????????
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    // ??????initCode UniswapV2Router?????????
    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(UniswapV2Pair).creationCode));

    constructor(address _feeToSetter) public {
        //  ?????????????????? ????????????????????????????????????
        feeToSetter = _feeToSetter;
    }

    // ????????????????????????????????????
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }


    // ??????????????????????????????????????????????????????token???address???
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // ????????????????????????????????????
        require(tokenA != tokenB, "UniswapV2: IDENTICAL_ADDRESSES");
        // ?????? ????????????????????????????????? ???
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // ?????????????????????????????????????????????0????????????token1???token0??????0?????????????????????1???????????????
        require(token0 != address(0), "UniswapV2: ZERO_ADDRESS");
        // ???????????????????????????????????????
        require(getPair[token0][token1] == address(0), "UniswapV2: PAIR_EXISTS"); // single check is sufficient
        // ????????? UniswapV2Pair ??????????????????????????? bytecode???????????????????????????16????????????
        // creationCode?????????????????????????????????????????????????????????
        // bytecode????????????????????????????????????????????????????????????????????????????????????bytecode????????????????????????????????????
        // creationCode??????????????????????????????add(creationCode, 32) 32??????????????????bytecode????????????32??????creationCode???????????????32???????????????creationCode??????
        // add(bytecode, 32) ????????????????????? mload(bytecode) ????????????
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        // console.log("create Pair bytecode bottom");
        // console.log(bytecode);
        // ???????????????token0???token1??????hash, ??????create2 ??? ?????????
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        // console.log(salt);
        // console.log(bytes1(0xff));
        assembly {
            // ??????create2 ??????????????????
            // create2(v, p, n, s)
            // v => ?????????????????????ETH ?????? wei ??? ??????
            // p => ??????????????????????????? 
            // n => ????????????;;;  mload(bytecode) ??????????????????????????????
            // s => ??? ?????????
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        console.log(token0);
        console.log(token1);
        console.log('pair',pair);
    
        // ????????????????????????????????????????????????????????????????????????????????????????????????create2?????? ???????????????????????????????????????
        IUniswapV2Pair(pair).initialize(token0, token1);
        // ?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        console.log("pair address", pair);
        // ?????????????????????????????????
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }
    // ?????????????????????????????????
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeTo = _feeTo;
    }
    // ????????????????????????????????????
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}

// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }
}

// a library for performing various math operations

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))

// range: [0, 2**112 - 1]
// resolution: 1 / 2**112
// UQ112x112??????????????????????????????
library UQ112x112 {
    // uint112 ?????????
    uint224 constant Q112 = 2**112;

    // UQ112x112 == uint224

    // encode a uint112 as a UQ112x112
    // ???????????? ?????? ?????????224???
    // ????????????????????????uint112???????????????????????????uint224
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    //  ????????????(y) ??????224????????????x ?????????????????????????????????uint224??????z???
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}