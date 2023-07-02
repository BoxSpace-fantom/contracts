// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import "./PriceFeed.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

abstract contract Wftminterface {
    function deposit() public virtual payable;
    function withdraw(uint wad) public virtual;
}

interface ERC20I {
    function decimals() external view returns (uint8);
}

contract BoxSpace is ERC1155Supply, PriceFeed {
    event Buy(uint boxId, uint buyAmount, uint boxTokenReceived);
    event Sell(uint boxId, uint sellAmount, uint amountReceived);
    event TokenSwapped(uint256 amountIn, uint256 amountOut);

    ISwapRouter public immutable swapRouter;
    Wftminterface wftmtoken;

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
    address ftmPriceFeed;

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
        ftmPriceFeed = 0xe04676B9A9A2973BCb0D1478b5E1E9098BBB7f3D;

        addToken("ftm", address(0), ftmPriceFeed);
        addToken("Wftm", 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83, ftmPriceFeed);

        wftmtoken = Wftminterface(tokenAddress["Wftm"]);
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

            if (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('ftm'))) {
                uint256 ftmAmount = msg.value * token.percentage / 100;
                boxBalance[boxId][address(this)] += ftmAmount;
                emit Buy(boxId, msg.value, ftmAmount);
            } else if (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('Wftm'))) {
                uint256 WftmAmount = msg.value * token.percentage / 100;
                wftmtoken.deposit{value: WftmAmount}();
                boxBalance[boxId][address(this)] += WftmAmount;
                emit Buy(boxId, msg.value, WftmAmount);
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

            if (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('ftm'))) {
                uint256 ftmAmount = boxBalance[boxId][address(this)] * amount / totalSupply(boxId);
                boxBalance[boxId][address(this)] -= ftmAmount;
                emit Sell(boxId, amount, ftmAmount);
                TransferHelper.safeTransferETH(msg.sender, ftmAmount);
            } else if (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('Wftm'))) {
                uint256 WftmAmount = boxBalance[boxId][address(this)] * amount / totalSupply(boxId);
                boxBalance[boxId][address(this)] -= WftmAmount;
                emit Sell(boxId, amount, WftmAmount);
                wftmtoken.withdraw(WftmAmount);
                TransferHelper.safeTransferETH(msg.sender, WftmAmount);
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

            if (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('ftm'))) {
                balance += buyAmount * token.percentage / 100;
            }
        }

        return buyAmount * totalSupply / balance;
    }
}
