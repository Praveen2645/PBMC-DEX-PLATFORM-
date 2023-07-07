// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

interface IWETH {
    function deposit() external payable;

    function transfer(address dst, uint256 wad) external returns (bool);

    function balanceOf(address to) external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function withdraw(uint256 wad) external;
}

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

contract EthPBMCPool {
    uint256 public totalLiquidity;
    IERC20 public PBMC;
    address public WETH;
    using SafeMath for uint256;

//EVENTS
  event LiquidityAdded(
    address indexed provider,
    uint256 amountPBMC,
    uint256 amountETH,
    uint256 liquidity
);

event LiquidityRemoved(
    address indexed provider,
    uint256 amountPBMC,
    uint256 amountUSDT,
    uint256 liquidity
);



    receive() external payable {}

    mapping(address => uint256) public userToMint;

    constructor() {}

    function setAddress(address _pbmc, address _WETH) external {
        PBMC = IERC20(_pbmc);
        WETH = _WETH;
    }

    bytes4 private constant SELECTOR =
        bytes4(keccak256(bytes("transfer(address,uint256)")));
    uint256 public reserveA;
    uint256 public reserveB;

    function safeTransferFrom(
        // address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = address(PBMC).call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper::transferFrom: transferFrom failed"
        );
    }


    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "safeTransferETH: ETH transfer failed");
    }

    function safeTransfer(address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = address(PBMC).call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper::safeTransfer: transfer failed"
        );
    }

    function addLiquidityETH(uint256 pbmcAmount, address to) external payable {
        uint256 amountToken;
        uint256 amountETH;

        (amountToken, amountETH) = _addLiquidity(pbmcAmount, msg.value);

        safeTransferFrom(msg.sender, address(this), amountToken);

        IWETH(WETH).deposit{value: amountETH}();
        IWETH(WETH).transfer(address(this), amountETH);

        mint(to);

        reserveA = PBMC.balanceOf(address(this));
        reserveB = IWETH(WETH).balanceOf(address(this));

        // Refund excess ETH, if any
        if (msg.value > amountETH) {
            // safeTransferETH(to, msg.value - amountETH);
            payable(msg.sender).transfer(msg.value - amountETH);
             emit LiquidityAdded(
        msg.sender,
        amountToken,
        amountETH,
        liquidity
    );

        }
        
        
    }

    function _addLiquidity(uint256 amountADesired, uint256 amountBDesired)
        internal
        view
        returns (uint256 amountA, uint256 amountB)
    {
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal <= amountBDesired, "Invalid amountb");

                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal <= amountADesired, "Invalid amountA");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function mint(address to) internal returns (uint256 liquidity) {
        (uint256 _reserveA, uint256 _reserveB) = getReserve();
        uint256 balance0 = PBMC.balanceOf(address(this));
        uint256 balance1 = IWETH(WETH).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserveA;
        uint256 amount1 = balance1 - _reserveB;

        uint256 _totalLiquidity = totalLiquidity;
        if (_totalLiquidity == 0) {
            liquidity = sqrt(amount0 * amount1);
        } else {
            liquidity = min(
                (amount0 * _totalLiquidity) / _reserveA,
                (amount1 * _totalLiquidity) / _reserveB
            );
        }
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        userToMint[to] += liquidity;
        totalLiquidity += liquidity;
    }

    function removeLiquidityETH(uint256 liquidity, address to)
        public
        returns (uint256 amountToken, uint256 amountETH)
    {
        require(userToMint[msg.sender] >=liquidity, "INSUFFICIENT_LIQUIDITY");
        (amountToken, amountETH) = burn(liquidity);
        userToMint[msg.sender] -= liquidity;
        safeTransfer(to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        safeTransferETH(to, amountETH);
        reserveA = PBMC.balanceOf(address(this));
        reserveB = IWETH(WETH).balanceOf(address(this));

         emit LiquidityRemoved(
        msg.sender,
        amountToken,
        amountETH,
        liquidity
    );
    }

    function burn(uint liquidity) internal returns (uint256 amountToken, uint256 amountETH) {
        uint256 balanceToken = PBMC.balanceOf(address(this));
        uint256 balanceETH = IWETH(WETH).balanceOf(address(this));
        uint256 _totalLiquidity = totalLiquidity;
        amountToken = (liquidity * balanceToken) / _totalLiquidity;
        amountETH = (liquidity * balanceETH) / _totalLiquidity;
        require(
            amountToken > 0 && amountETH > 0,
            "INSUFFICIENT_LIQUIDITY_BURNED"
        );
        totalLiquidity -= liquidity;
    }

    function swap() internal {
        {
            reserveA = IERC20(PBMC).balanceOf(address(this));
            reserveB = IWETH(WETH).balanceOf(address(this));
        }
    }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address to
    ) external {
        require(amountOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        (uint256 reserveIn, uint256 reserveOut) = getReserve();
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint256 numerator = (reserveIn * amountOut * 1000);
        uint256 denominator = (reserveOut - amountOut) * (997);
        uint256 amountIn = (numerator / denominator) + (1);
        require(amountIn <= amountInMax, "EXCESSIVE_ETH_AMOUNT");
        require(amountOut <= reserveOut, "INSUFFICIENT LIQUIDITY");
        safeTransferFrom(msg.sender, address(this), amountIn);
        IWETH(WETH).withdraw(amountOut);
        safeTransferETH(to, amountOut);
        swap();

   
    }

    function swapETHForExactTokens(uint256 amountOut, address to)
        external
        payable
    {
        require(amountOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        (uint256 reserveOut, uint256 reserveIn) = getReserve();
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        
        uint256 numerator = (reserveIn * amountOut * 1000);
        uint256 denominator = (reserveOut - amountOut) * (997);
        uint256 amountIn = (numerator / denominator) + (1);

        require(amountIn <= msg.value, "EXCESSIVE_INPUT_AMOUNT");
        require(amountOut <= reserveOut, "INSUFFICIENT_LIQUIDITY");

        IWETH(WETH).deposit{value: amountIn}();
        IWETH(WETH).transfer(address(this), amountIn);
        PBMC.transfer(to, amountOut);
        if (msg.value > amountIn){
            safeTransferETH(msg.sender, msg.value - amountIn);
        }
        swap();
    }

    function swapExactTokensForETH(uint256 amountIn, address to) external {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        (uint256 reserveIn, uint256 reserveOut) = getReserve();
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        uint256 amountOut = numerator / denominator;
        require(amountOut <= reserveOut, "INSUFFICIENT LIQUIDITY");
        safeTransferFrom(msg.sender, address(this), amountIn);
        IWETH(WETH).withdraw(amountOut);
        safeTransferETH(to, amountOut);
        swap();
    }

    function swapExactETHForTokens(address to) external payable {
        require(msg.value > 0, "INSUFFICIENT_ETH_AMOUNT");
        (uint256 reserveOut, uint256 reserveIn) = getReserve();
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = (msg.value).mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        uint256 amountOut = numerator / denominator;
        require(amountOut <= reserveOut, "INSUFFICIENT_LIQUIDITY");
        IWETH(WETH).deposit{value: msg.value}();
        IWETH(WETH).transfer(address(this), msg.value);
        PBMC.transfer(to, amountOut);
        swap();
    }

    function getReserve()
        public
        view
        returns (uint256 _reserveA, uint256 _reserveB)
    {
        _reserveA = reserveA;
        _reserveB = reserveB;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }
}


