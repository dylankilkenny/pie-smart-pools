pragma solidity ^0.6.4;

import "../interfaces/IPSmartPool.sol";
import "../interfaces/IBPool.sol";
import "../balancer-math/BMath.sol";
import "../Ownable.sol";

contract PSingleAssetJoinExitRecipe is BMath, Ownable {

    IPSmartPool public pool;
    IBPool public bPool;

    constructor(address _pool) public {
        pool = IPSmartPool(_pool);
        bPool = IBPool(pool.getBPool());
        _setOwner(msg.sender);
    }

    function joinswapExternAmountIn(address _tokenIn, uint256 _tokenAmountIn, uint256 _minPoolAmountOut) external returns(uint256) {

        IERC20(_tokenIn).transferFrom(msg.sender, address(this), _tokenAmountIn);
        uint256 poolAmountOut;
        uint256 poolSupply;

        // Create seperate scope to prevent stack to deep errors
        {
            uint256 tokenBalanceIn = bPool.getBalance(_tokenIn);
            uint256 tokenWeightIn = bPool.getDenormalizedWeight(_tokenIn);
            poolSupply = pool.totalSupply();
            uint256 totalWeight = bPool.getTotalDenormalizedWeight();
            uint256 swapFee = bPool.getSwapFee();
            // Some weird rounding  happening so we skim 1% of the input
            poolAmountOut = calcPoolOutGivenSingleIn(tokenBalanceIn, tokenWeightIn, poolSupply, totalWeight, _tokenAmountIn, swapFee * 2);
        }

        require(poolAmountOut >= _minPoolAmountOut, "AMOUNT TOO LOW");
        
        uint256 newTotalSupply = badd(poolSupply, poolAmountOut);

        address[] memory tokens = bPool.getCurrentTokens();

        // approve token
        IERC20(_tokenIn).approve(address(bPool), uint256(-1));

        // Buy the other underlying tokens
        for (uint i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).approve(address(pool), uint256(-1));
            // No need to buy this token
            if(tokens[i] == _tokenIn) {
                continue;
            }

            // Some weird rounding happening so buying 1 extra unit
            uint256 tokensNeeded = bPool.getBalance(tokens[i]) * poolAmountOut / (newTotalSupply) + 1;

            bPool.swapExactAmountOut(_tokenIn, uint256(-1), tokens[i], tokensNeeded, uint256(-1));
            
        }

        pool.joinPool(poolAmountOut);

        pool.transfer(msg.sender, poolAmountOut);

        return poolAmountOut;
    }   

    function pullToken(address _token) external onlyOwner {
        IERC20 token = IERC20(_token);
        token.transfer(msg.sender, token.balanceOf(address(this)) - 1);
    }

    // calcPoolOutGivenSingleIn(tokenBalanceIn, tokenWeightIn, poolSupply, totalWeight, _tokenAmountIn, swapFee * 2);
    function calcPoolOutGivenSingleIn(address _tokenIn, uint256 _tokenAmountIn) external view returns(uint256) {
        uint256 tokenBalanceIn = bPool.getBalance(_tokenIn);
        uint256 tokenWeightIn = bPool.getDenormalizedWeight(_tokenIn);
        uint256 poolSupply = pool.totalSupply();
        uint256 totalWeight = bPool.getTotalDenormalizedWeight();
        uint256 swapFee = bPool.getSwapFee();
        // Some weird rounding  happening so we skim 1% of the input
        uint256 poolAmountOut = calcPoolOutGivenSingleIn(tokenBalanceIn, tokenWeightIn, poolSupply, totalWeight, _tokenAmountIn, swapFee * 2);

        return poolAmountOut;
    }
    
    function exitswapPoolAmountIn(address _tokenOut, uint256 _poolAmountIn, uint256 _minAmountOut) external returns(uint256) {
        pool.transferFrom(msg.sender, address(this), _poolAmountIn);
        pool.exitPool(_poolAmountIn);
        
        address[] memory tokens = bPool.getCurrentTokens();

        for(uint i = 0; i < tokens.length; i++) {
            if(tokens[i] == _tokenOut) {
                continue;
            }

            IERC20 token = IERC20(tokens[i]);
            token.approve(address(bPool), uint256(-1));
            bPool.swapExactAmountIn(tokens[i], token.balanceOf(address(this)), _tokenOut, 0, uint256(-1));
        }


        IERC20 tokenOut = IERC20(_tokenOut);
        uint256 tokenOutBalance = tokenOut.balanceOf(address(this));
        require(tokenOutBalance >= _minAmountOut);

        tokenOut.transfer(msg.sender, tokenOutBalance);
        return tokenOutBalance;
    }

    function calcSingleOutGivenPoolIn(address _tokenOut, uint256 _poolIn) external view returns(uint256) {
        uint256 tokenBalanceOut = bPool.getBalance(_tokenOut);
        uint256 tokenWeightOut = bPool.getDenormalizedWeight(_tokenOut);
        uint256 poolSupply = pool.totalSupply();
        uint256 totalWeight = bPool.getTotalDenormalizedWeight();
        uint256 swapFee = bPool.getSwapFee();

        return calcSingleOutGivenPoolIn(tokenBalanceOut, tokenWeightOut, poolSupply, totalWeight, _poolIn, swapFee * 2);
    }

}