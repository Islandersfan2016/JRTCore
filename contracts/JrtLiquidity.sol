// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import ".deps/npm/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IJackrabbitV2Factory.sol";
import "./interfaces/IJackrabbitV2Router02.sol";
contract JrtLiquidity {
  address private constant FACTORY = 0x5934873D064f6b544918C7481d71F4806742Be58;
  address private constant ROUTER = 0xC6E38122bed2a2307982F7A8902136e8D5bbeaD7;
  address private constant WETH = ;
  address private constant FIL = ;
  event Log(string message, uint val);
  function addLiquidity(
    address _tokenA,
    address _tokenB,
    uint _amountA,
    uint _amountB
  ) external {
    IERC20(_tokenA).transferFrom(msg.sender, address(this), _amountA);
    IERC20(_tokenB).transferFrom(msg.sender, address(this), _amountB);
    IERC20(_tokenA).approve(ROUTER, _amountA);
    IERC20(_tokenB).approve(ROUTER, _amountB);
    (uint amountA, uint amountB, uint liquidity) =
      IJackrabbitV2Router02(ROUTER).addLiquidity(
        _tokenA,
        _tokenB,
        _amountA,
        _amountB,
        1,
        1,
        address(this),
        block.timestamp
      );
    emit Log("amountA", amountA);
    emit Log("amountB", amountB);
    emit Log("liquidity", liquidity);
  }
  function removeLiquidity(address _tokenA, address _tokenB) external {
    address pair = IJackrabbitV2Factory(FACTORY).getPair(_tokenA, _tokenB);
    uint liquidity = IERC20(pair).balanceOf(address(this));
    IERC20(pair).approve(ROUTER, liquidity);
    (uint amountA, uint amountB) =
      IJackrabbitV2Router02(ROUTER).removeLiquidity(
        _tokenA,
        _tokenB,
        liquidity,
        1,
        1,
        address(this),
        block.timestamp
      );
    emit Log("amountA", amountA);
    emit Log("amountB", amountB);
  }
}





