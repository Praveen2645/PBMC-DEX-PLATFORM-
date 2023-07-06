pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol";

library SafeMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }
}

contract GLDToken is ERC20 {
    constructor(uint256 initialSupply) public ERC20("TOKEN1", "TOKEN1") {
        _mint(msg.sender, initialSupply);
    }
}

contract USDT is ERC20 {
    constructor(uint256 initialSupply) public ERC20("USDT", "USDT") {
        _mint(msg.sender, initialSupply);
    }
}

//0xE136dea62A97f30863Be40183de6efff56890537 gld token
//0xa0173ad8Aeb4FC766164700E7eC8c0E17070E0CE liquidity

contract Liquidity {
    uint256 public reserve1;
    uint256 public reserve2;
    IERC20 public token1;
    IERC20 public token2;
    uint256 public totalLiquidity;
    uint256 public totalSupply;
    mapping(address => uint256) public userLiquidity;
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    using SafeMath for uint256;

    constructor() {}

    function setAddresses(address _token1, address _token2) public {
        token1 = IERC20(_token1);
        token2 = IERC20(_token2);
    }

    function getReserves()
        public
        view
        returns (uint256 _reserve1, uint256 _reserve2)
    {
        _reserve1 = reserve1;
        _reserve2 = reserve2;
    }

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256) {
        require(amountA > 0, "UniswapV2Library: INSUFFICIENT_AMOUNT");
        require(
            reserveA > 0 && reserveB > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountB = amountA.mul(reserveB) / reserveA;
        return amountB;
    }

    function _addLiquidity(
        uint256 _token1Quantity,
        uint256 _token2Quantity,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        require(
            _token1Quantity != 0 && _token2Quantity != 0,
            "token quantity could not be zero"
        );
        (uint256 reserveA, uint256 reserveB) = getReserves();
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (_token1Quantity, _token2Quantity);
        } else {
            uint256 amount2Optimal = quote(_token1Quantity, reserveA, reserveB);
            if (amount2Optimal <= _token2Quantity) {
                require(
                    amount2Optimal >= amountBMin,
                    "UniswapV2Router: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (_token1Quantity, _token2Quantity);
            } else {
                uint256 amountAOptimal = quote(
                    _token2Quantity,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= _token1Quantity);
                require(
                    amountAOptimal >= amountAMin,
                    "UniswapV2Router: INSUFFICIENT_A_AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, _token2Quantity);
            }
        }
    }

    function addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB) = _addLiquidity(
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        token1.transferFrom(msg.sender, address(this), amountA);
        token2.transferFrom(msg.sender, address(this), amountB);
        liquidity = mintLPToken(to);
    }

    function mintLPToken(address to) public returns (uint256 liquidity) {
        (uint256 _reserve0, uint256 _reserve1) = getReserves(); // gas savings
        uint256 balance0 = token1.balanceOf(address(this));
        uint256 balance1 = token2.balanceOf(address(this));
        uint256 amount0 = balance0.sub(_reserve0);
        uint256 amount1 = balance1.sub(_reserve1);

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            userLiquidity[address(0)] = MINIMUM_LIQUIDITY;
        } else {
            liquidity = Math.min(
                amount0.mul(_totalSupply) / _reserve0,
                amount1.mul(_totalSupply) / _reserve1
            );
        }
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");

        userLiquidity[to] += liquidity;
        totalSupply += liquidity;
        reserve1 = balance0;
        reserve2 = balance1;
    }

    function burn(address to, uint256 liquidity)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 _reserve0, uint256 _reserve1) = getReserves();
        uint256 balance0 = token1.balanceOf(address(this));
        uint256 balance1 = token2.balanceOf(address(this));

        require(
            liquidity <= userLiquidity[to],
            "liquidity is more than the balance"
        );
        uint256 _totalSupply = totalSupply;
        amount0 = liquidity.mul(balance0) / _totalSupply;
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_BURNED");
        userLiquidity[to] -= liquidity;
        totalSupply -= liquidity;

        token1.approve(address(this), amount0);
        token1.transfer(to, amount0);
        token2.transfer(to, amount1);
        balance0 = token1.balanceOf(address(this));
        balance1 = token2.balanceOf(address(this));
        reserve1 = balance0;
        reserve2 = balance1;
    }

    function removeLiquidity(uint256 liquidity, address to)
        public
        returns (uint256 amountA, uint256 amountB)
    {
        (amountA, amountB) = burn(to, liquidity);
    }

    function swapTokenForUSDT(uint256 amountIn, address _to) external {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        token1.transferFrom(_to, address(this), amountIn); // optimistically transfer tokens
        (uint256 reserveIn, uint256 reserveOut) = getReserves();

        // require(amount0In > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        uint256 amountOut = numerator / denominator;
        // _swap(amount0Out, amount1Out, _to);
        require(amountOut < reserveOut, "UniswapV2: INSUFFICIENT_LIQUIDITY");
        token2.transfer(_to, amountOut);
        reserve2 -= amountOut;
    }

    function swapUSDTForToken(uint256 amountIn, address _to) external {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        token1.transferFrom(_to, address(this), amountIn); // optimistically transfer tokens
        (uint256 reserveOut, uint256 reserveIn) = getReserves();
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        uint256 amountOut = numerator / denominator;
        require(amountOut < reserveOut, "UniswapV2: INSUFFICIENT_LIQUIDITY");
        token1.transfer(_to, amountOut);
        reserve1 -= amountOut;
    }
}
