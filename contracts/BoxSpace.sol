// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import "./PriceFeed.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

abstract contract WDEVinterface {
    function deposit() public virtual payable;
    function withdraw(uint wad) public virtual;
}

interface ERC20I {
    function decimals() external view returns (uint8);
}

contract BoxDefi is ERC1155Supply, PriceFeed {
    event Buy(uint boxId, uint buyAmount, uint boxTokenReceived);
    event Sell(uint boxId, uint sellAmount, uint amountReceived);
    event TokenSwapped(uint256 amountIn, uint256 amountOut);

    ISwapRouter public immutable swapRouter;
    WDEVinterface wdevtoken;

    uint24 public constant poolFee = 30;
    uint8 constant DECIMAL = 2;
    address owner;

    struct Token {
        string name;
        uint8 percentage;
    }

    mapping(uint24 => Token[]) boxDistribution;
    mapping(uint24 => mapping(address => uint256)) public boxBalance;
    mapping(string => address) tokenAddress;
    mapping(string => address) tokenPriceFeed;
    address DEVPriceFeed;

    uint24 boxNumber;

    modifier checkBoxID(uint24 boxId) {
        require(boxId < boxNumber, "Invalid BoxID parameter.");
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Owner access only");
        _;
    }

    constructor() ERC1155(" ") PriceFeed() {
        owner = msg.sender;
        swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        DEVPriceFeed = 0xa39d8684B8cd74821db73deEB4836Ea46E145300;

        addToken("DEV", address(0), DEVPriceFeed);
        addToken("WDEV", 0x7128AF8F5AA6abe92b5f9ba9545146027A995B16, DEVPriceFeed);

        wdevtoken = WDEVinterface(tokenAddress["WDEV"]);
    }

    function addToken(string memory _tokenSymbol, address _tokenAddress, address _tokenPriceFeed) public onlyOwner {
        tokenAddress[_tokenSymbol] = _tokenAddress;
        tokenPriceFeed[_tokenSymbol] = _tokenPriceFeed;
    }

    function buy(uint24 boxId) external payable checkBoxID(boxId) returns (uint256 boxTokenMinted) {
        require(msg.value > 0, "msg.value is 0");

        uint256 tokenMintAmount = _getBoxTokenMintAmount(boxId, msg.value);

        uint256 tokensInBox = getNumberOfTokensInBox(boxId);
        for (uint256 i = 0; i < tokensInBox; i++) {
            Token memory token = boxDistribution[boxId][i];

            if (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('DEV'))) {
                uint256 DEVAmount = msg.value * token.percentage / 100;
                boxBalance[boxId][address(this)] += DEVAmount;
                emit Buy(boxId, msg.value, DEVAmount);
            } else if (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WDEV'))) {
                uint256 WDEVAmount = msg.value * token.percentage / 100;
                wdevtoken.deposit{value: WDEVAmount}();
                boxBalance[boxId][address(this)] += WDEVAmount;
                emit Buy(boxId, msg.value, WDEVAmount);
            }
        }

        _mint(msg.sender, boxId, tokenMintAmount, "");

        return tokenMintAmount;
    }

    function sell(uint24 boxId, uint256 amount) external checkBoxID(boxId) {
        require(balanceOf(msg.sender, boxId) >= amount, "Insufficient box tokens");

        uint256 tokensInBox = getNumberOfTokensInBox(boxId);
        for (uint256 i = 0; i < tokensInBox; i++) {
            Token memory token = boxDistribution[boxId][i];

            if (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('DEV'))) {
                uint256 DEVAmount = boxBalance[boxId][address(this)] * amount / totalSupply(boxId);
                boxBalance[boxId][address(this)] -= DEVAmount;
                emit Sell(boxId, amount, DEVAmount);
                TransferHelper.safeTransferETH(msg.sender, DEVAmount);
            } else if (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WDEV'))) {
                uint256 WDEVAmount = boxBalance[boxId][address(this)] * amount / totalSupply(boxId);
                boxBalance[boxId][address(this)] -= WDEVAmount;
                emit Sell(boxId, amount, WDEVAmount);
                wdevtoken.withdraw(WDEVAmount);
                TransferHelper.safeTransferETH(msg.sender, WDEVAmount);
            }
        }

        _burn(msg.sender, boxId, amount);
    }

    function swapTokens(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        uint160 _sqrtPriceLimitX96
    ) external returns (uint256 amountOut) {
        TransferHelper.safeTransferFrom(_tokenIn, msg.sender, address(this), _amountIn);
        TransferHelper.safeApprove(_tokenIn, address(swapRouter), _amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: _amountOutMin,
            sqrtPriceLimitX96: _sqrtPriceLimitX96
        });

        amountOut = swapRouter.exactInputSingle(params);

        TransferHelper.safeTransfer(_tokenOut, msg.sender, amountOut);

        emit TokenSwapped(_amountIn, amountOut);
    }

      function getNumberOfTokensInBox(uint24 boxId) public view checkBoxID(boxId) returns(uint){
        return(boxDistribution[boxId].length);
    }

    function _getBoxTokenMintAmount(uint24 boxId, uint256 buyAmount) private view returns (uint256) {
        uint256 totalSupply = totalSupply(boxId);
        if (totalSupply == 0) {
            return buyAmount;
        }

        uint256 balance = boxBalance[boxId][address(this)];
        uint256 tokensInBox = getNumberOfTokensInBox(boxId);

        for (uint256 i = 0; i < tokensInBox; i++) {
            Token memory token = boxDistribution[boxId][i];

            if (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('DEV'))) {
                balance += buyAmount * token.percentage / 100;
            }
        }

        return buyAmount * totalSupply / balance;
    }
}
