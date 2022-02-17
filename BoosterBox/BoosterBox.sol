// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Get a link to NFT contract
interface NFT {

  function mint(address to, uint256 id) external;

  function setCategory(uint id, uint category) external;

}

// Get a link to payment token contract
interface IPaymentToken {
  
  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  function burnFrom(address account, uint256 amount) external;

}

// Get a link to price feed contract
interface IPriceFeed {

  function getPriceinUSD(address tokenAddress) external view returns (uint256);

}

// Get a link to random feed contract
interface IRandomFeed {

  function getRandomFeed(uint256 salt) external returns(uint256 id, uint256 category);

}

/**
   * @title BoosterBox Version 1.0
   *
   * @author GambleFiDAO
   */
contract BoosterBox {

  //---sell parameters---//  
  uint256 public itemsSold;
  uint256 public items;
  uint256 public price;

  //---Set of addresses---// 
  address public admin;
  address public treasury;
  address public dev;
  address public nftContract;
  address public stableToken;
  address public daoToken;

  address private priceFeed;
  address private randomFeed;

  //---Box Control Variable---//
  uint8 public percentageBCV;
  uint8 public valueBCV; // 0 = negative value, 1 = positive value 

  //-----Features-----//
  // 0 = mint is disabled, 1 = mint with stable token is enabled,
  // 2 = mint with DAO token is enabled, 3 = mint with both token is enabled 
  uint8 public feature;   
  
  /**
	   * @dev Fired in initializeSell()
	   *
     * @param _by an address of owner who executes the function
	   * @param _mintPrice minting price in terms of stable token per BoosterBox
     * @param _items number of BoosterBox to be sold
     */
  event Initialize(
    address indexed _by,
    uint256 _mintPrice,
    uint _items     
  );

  /**
	   * @dev Fired in setBCV()
	   *
     * @param _by an address of owner who executes the function
	   * @param _percentage BCV percentage
     * @param _value BCV value (0 = negative value, 1 = positive value)
     */
  event BCVUpdated(
    address indexed _by,
    uint8 _percentage,
    uint8 _value
  );

  /**
	   * @dev Fired in setFeature()
	   *
     * @param _by an address of owner who executes the function
	   * @param _feature defines feature code
     */
  event FeatureUpdated(
    address indexed _by,
    uint8 _feature
  );

  /**
	   * @dev Creates/deploys BoosterBox Version 1.0
	   *
	   * @param admin_ address of admin
     * @param treasury_ address of treasury
     * @param dev_ address of dev
     * @param nftContract_ address of BoosterNFT smart contract
     * @param stableToken_ address of stable token
     * @param daoToken_ address of DAO token
     * @param priceFeed_ address of priceFedd contract
     * @param randomFeed_ address of randomFeed contract
	   */
  constructor(
      address admin_,
      address treasury_,
      address dev_,
      address nftContract_,
      address stableToken_,
      address daoToken_,
      address priceFeed_,
      address randomFeed_
    )
  {
    //---Setup smart contract internal state---//
    admin = admin_;
    treasury = treasury_;
    dev = dev_;
    nftContract = nftContract_;
    stableToken = stableToken_;
    daoToken = daoToken_;
    priceFeed = priceFeed_;
    randomFeed = randomFeed_;
  }

  /**
	   * @dev Initialize sell parameters
	   *
     * @notice same function can be used to reinitialize parameters,
     *         arguments should be placed carefully for reinitialization/ 
     *         modification of sell parameter 
     *
	   * @param mintPrice_ minting price in terms of stable token per BoosterBox
     * @param items_ total number of BoosterBox to be sold
	   */
  function initializeSell(uint256 mintPrice_, uint items_)
    external
  {
    require(msg.sender == admin, "Only admin can initialize sell");
    
    // Set up sell parameters
    price = mintPrice_;
    items = items_;

    // Emits an event
    emit Initialize(msg.sender, mintPrice_, items_);  
  }

  /**
	   * @dev Sets Box Control Variable
	   * 
	   * @param percentage_ BCV percentage
     * @param value_ BCV value (0 = negative value, 1 = positive value)
     */
  function setBCV(uint8 percentage_, uint8 value_)
    external
  {
    require(msg.sender == admin, "Only admin can set BCV");
    
    require(percentage_ <= 100 && value_ <= 1, "Invalid input");
    
    //--- Set up BCV parameters ---//
    percentageBCV = percentage_;
    
    valueBCV = value_;

    //Emits an event
    emit BCVUpdated(msg.sender, percentage_, value_);
  }

  /**
	   * @dev Sets feature
	   * 
	   * @param feature_ defines feature code
     */
  function setFeature(uint8 feature_)
    external
  {
    require(msg.sender == admin, "Only admin can set feature");
    
    require(feature_ <= 3, "Invalid input");
    
    // Set feature
    feature = feature_;

    // Emits an event
    emit FeatureUpdated(msg.sender, feature_);
  }
  
  /**
	   * @dev Sets stable token contract address
	   * 
	   * @param stable_ stable token contract address
     */
  function setStableTokenAddress(address stable_)
    external
  {
    require(msg.sender == admin, "Only admin can set randomFeed");
    
    // Set stableToken address
    stableToken = stable_;
  }

  /**
	   * @dev Sets DAO token contract address
	   * 
	   * @param dao_ DAO token contract address
     */
  function setDAOTokenAddress(address dao_)
    external
  {
    require(msg.sender == admin, "Only admin can set randomFeed");
    
    // Set daoToken address
    daoToken = dao_;
  }

  /**
	   * @dev Sets price feed contract address
	   * 
	   * @param priceFeed_ price feed token contract address
     */
  function setPriceFeedAddress(address priceFeed_)
    external
  {
    require(msg.sender == admin, "Only admin can set priceFeed");
    
    // Set priceFeed address
    priceFeed = priceFeed_;
  }
  
  /**
	   * @dev Sets random feed contract address
	   * 
	   * @param randomFeed_ random feed contract address
     */
  function setRandomFeedAddress(address randomFeed_)
    external
  {
    require(msg.sender == admin, "Only admin can set randomFeed");
    
    // Set randomFeed address
    randomFeed = randomFeed_;
  }

  /**
	   * @dev Mints Booster NFTs by paying price in stable token 
	   * 
	   * @param amount_ number NFTs to buy
     */
  function mintWithStableToken(uint amount_) external {    
    
    require(feature == 1 || feature == 3, "Feature disabled");

    // Calculate mint price in stable token
    uint256 _mintPrice =  price * amount_;

    // Transfer proceedings to dev and treasury address
    IPaymentToken(stableToken).transferFrom(msg.sender, dev, _mintPrice / 10);

    IPaymentToken(stableToken).transferFrom(msg.sender, treasury, (_mintPrice - _mintPrice / 10));

    require(itemsSold + amount_ <= items, "Not enough NFTs left");
    
    for(uint i=0; i < amount_; i++) {
      // Get id and category to be assigned to minted NFT
      (uint256 id, uint256 category) = IRandomFeed(randomFeed).getRandomFeed(itemsSold * _mintPrice * i);
      // Mint an NFT
      NFT(nftContract).mint(msg.sender, id);
      // Set the category of minted NFT
      NFT(nftContract).setCategory(id, category);
      // Increment sold counter
      itemsSold++;
    }

  }
  
  /**
	   * @dev Mints Booster NFTs by paying price in DAO token 
	   * 
	   * @param amount_ number NFTs to buy
     */
  function mintWithDAOToken(uint amount_) external {    
    
    require(feature == 2 || feature == 3, "Feature disabled");

    // Calculate mint price in DAO token
    uint256 _mintPrice = calculateDAOPrice(price) * amount_;

    // Burn DAO tokens
    IPaymentToken(daoToken).burnFrom(msg.sender, _mintPrice);

    require(itemsSold + amount_ <= items, "Not enough NFTs left");

    for(uint i=0; i < amount_; i++) {
      // Get id and category to be assigned to minted NFT  
      (uint256 id, uint256 category) = IRandomFeed(randomFeed).getRandomFeed(itemsSold * _mintPrice * i);
      // Mint an NFT
      NFT(nftContract).mint(msg.sender, id);
      // Set the category of minted NFT
      NFT(nftContract).setCategory(id, category);
      // Increment sold counter
      itemsSold++;
    }

  }

  /**
	 * @dev Calculates Item price in terms of DAO Token 
	 */
  function calculateDAOPrice(uint256 itemPriceInUSD_) public view returns(uint256) {
    // Get dao token price in terms of stable token
    uint256 _daoPriceInUSD = IPriceFeed(priceFeed).getPriceinUSD(daoToken);
    
    // Calculate item price in terms of dao token
    uint256 _itemPriceInDAO = (itemPriceInUSD_ * 1e9) / _daoPriceInUSD;

    // Calculate final price based on BCV
    uint256 _finalPrice = (valueBCV == 0) 
                        ?  (_itemPriceInDAO + ((_itemPriceInDAO * percentageBCV) / 100))
                        :  (_itemPriceInDAO - ((_itemPriceInDAO * percentageBCV) / 100));
    
    // Return final price based on BCV
    return _finalPrice;
  }

  /**
     * @dev Withdraw tokens 
     * 
     * @param token_ address of token
     */
  function withdrawTokens(address token_) external {
    
    require(msg.sender == admin, "Only admin can withdraw tokens");

    // Fetch balance of the contract  
    uint _balance = IPaymentToken(token_).balanceOf(address(this));
    
    require(_balance > 0, "Zero balance");
    
    // transfer tokens to owner if balance is non-zero
    IPaymentToken(token_).transfer(msg.sender, _balance);
      
  }

}