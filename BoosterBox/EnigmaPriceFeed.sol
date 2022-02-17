// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor() {}

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IJeoSwap {
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract EnigmaPriceFeed is Ownable {
    
    address immutable public joeRouterAddress;
    address immutable public pairTokenAddress;
    uint256 public lowerThreshold;
    uint256 public higherThreshold;

    IJeoSwap private jeoSwap;

    constructor (address _routerAddress, address _pairTokenAddress, uint256 _lowerThreshold, uint256 _higherThreshold) {
        require(_routerAddress != address(0x0), 'routerAddress should be valid Address');
        require(_pairTokenAddress != address(0x0), 'pairToken should be valid Address');
        require(_lowerThreshold < _higherThreshold, 'Invalid Input');

        lowerThreshold = _lowerThreshold;
        higherThreshold = _higherThreshold;

        joeRouterAddress = address(_routerAddress);
        pairTokenAddress = address(_pairTokenAddress);
        jeoSwap = IJeoSwap(_routerAddress);

    }

    modifier isAllowed() {
        require(
            _msgSender() == owner(),
            "EnigmaPriceFeed: Operation not allowed"
        );
        _;
    }

    function getPriceinUSD(address _tokenAddr) external view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = _tokenAddr; 
        path[1] = pairTokenAddress;

        uint256[] memory amounts  = jeoSwap.getAmountsOut(10 * 10 ** IERC20(_tokenAddr).decimals(), path);
        uint256 price = amounts[amounts.length -1] / 10;

        if (price > higherThreshold) {
            price = higherThreshold;
        } else if (price < lowerThreshold) {
            price = lowerThreshold;
        }    
        return price;
    }

    function setPriceRange(uint256 _lowerThreshold, uint256 _higherThreshold) external isAllowed {
        require(_lowerThreshold < _higherThreshold, 'Invalid Input');
        lowerThreshold = _lowerThreshold;
        higherThreshold = _higherThreshold;
    }
}
