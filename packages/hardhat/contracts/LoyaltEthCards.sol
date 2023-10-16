//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./PartnerVendorContract.sol";

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * A smart contract that mint Referals NFT, only owner can mint an nft to his customer, By mintig he gives adavantage to his customer (like buy 10 get 10% cashback)
 * This has not be audited, this smart contract is only for a education purpose ! Please DO NOT USE IT IN PRODUCTION
 * @author cmaranber.eth
 */



contract LoyaltEthCards is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
   // AggregatorV3Interface internal priceFeed;

    using Strings for uint256;
    using Strings for uint8;
    using Counters for Counters.Counter; 

    uint256 public ETH_PRICE = 1500; //@todo has to be removed and use oracle instead ! 
    Counters.Counter private _tokenIds;
    struct Metadata {
       string url;
       uint8 required;
       uint256 validity;
       uint256 deadLine; 
       uint8 percent;
    }

    Metadata private metadata;
    address public factoryAddress;
    address payable public partnerVendorAddress;
    mapping(uint256 => uint8) public tokenIdUsed; //how many times the nft have been used 
    mapping(uint256 => bool) public tokenIsActive; 
    mapping(uint256 => Metadata) public tokenIdMetadata;
    PartnerVendorContract public partnerVendorContract; //@todo set to private after tests
     uint8 public required;
    string public url;
    uint256 public validity;
    uint8 public percent;

    /*@Params:
    * _factoryAddress: address of the factory contract that deployed this contract.
    * _required: number of iteration before the reward can be withdraw
    * url: the url of the service that is proposed by the partner
    * validity: duration of validity 'in days' (if the card is not full befor the validity, the partner can withdraw the reward, if the card is full befor the deadLine the customer can withdraw his reward)
    * _percent: the percentage of cashBack that you get if you use _required times before the deadLine
    */
    constructor(address _factoryAddress, uint8 _required, string memory _url, uint256 _validity, uint8 _percent) ERC721("LoyaltEthCard", "LETH") { //should pass the oracle contract address in the constructor for eth price
        require ((_percent < 100) && (_percent > 0), "put a number between 1 and 99");
        factoryAddress=_factoryAddress;
        required = _required; 
        url = _url; 
        validity = _validity;
        percent = _percent;
    } 

    modifier onlyFactory (){ 
        require(msg.sender == factoryAddress, "Not the factory");
        _;
    }
    modifier onlyPartner (){
        require(msg.sender == partnerVendorAddress, "Not the partner");
        _;
    }

    function setParnerVendorAddress (address _partnerVendorAddress ) public onlyFactory {
        partnerVendorAddress = payable(_partnerVendorAddress);
        partnerVendorContract = PartnerVendorContract(partnerVendorAddress);
    } 

    function generateCard(uint256 tokenId) public view returns(string memory){
        bytes memory svg;
        if (tokenIsActive[tokenId]) {
             svg = abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="300px" height="300px" preserveAspectRatio="xMinYMin meet" viewBox="0 0 300 300">',
                '<style>.base { fill: black; font-family: serif; font-size: 14px; }</style>',
                '<rect width="100%" height="100%" fill="white" />',
                '<text x="5%" y="20%" class="base" dominant-baseline="middle" text-anchor="start">',"LoyaltEth Cards #", (tokenId).toString(), '</text>',
                '<text x="95%" y="20%" class="base" dominant-baseline="middle" text-anchor="end">', getUsed(tokenId), " / " ,getMetadataRequired(tokenId),'</text>',
                '<a href="',getUrl(tokenId),'" target="_blank">',
                '<text x="50%" y="50%" class="base" dominant-baseline="middle" text-anchor="middle">', getUrl(tokenId),'</text>',
                '</a>',
                '<text x="50%" y="60%" class="base" dominant-baseline="middle" text-anchor="middle">', "Use Befor : ", getDeadLine(tokenId), " days",'</text>',
                '<text x="50%" y="70%" class="base" dominant-baseline="middle" text-anchor="middle">', "Reward : ", getReward(tokenId), " %",'</text>',
                '<text x="95%" y="85%" class="base" dominant-baseline="middle" text-anchor="end">', getBalance(tokenId), " GWEI", '</text>',
                '<text x="95%" y="95%" class="base" dominant-baseline="middle" text-anchor="end">', getUsdBalance(tokenId), " USD", '</text>',
                '</svg>'
        );} else {
            svg = abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="300px" height="300px" preserveAspectRatio="xMinYMin meet" viewBox="0 0 300 300">',
                '<style>.base { fill: black; font-family: serif; font-size: 14px; }</style>',
                '<rect width="100%" height="100%" fill="grey" />',
                '<text x="5%" y="20%" class="base" dominant-baseline="middle" text-anchor="start">',"LoyaltEth Cards #", (tokenId).toString(), '</text>',
                '<text x="95%" y="20%" class="base" dominant-baseline="middle" text-anchor="end">', getUsed(tokenId), " / " ,getMetadataRequired(tokenId),'</text>',
                '<a href="',getUrl(tokenId),'" target="_blank">',
                '<text x="50%" y="50%" class="base" dominant-baseline="middle" text-anchor="middle">', getUrl(tokenId),'</text>',
                '</a>',
                '<text x="50%" y="60%" class="base" dominant-baseline="middle" text-anchor="middle">', "YOUR LOYALTETH CARD IS INACTIVE",'</text>',
                
                '<text x="95%" y="85%" class="base" dominant-baseline="middle" text-anchor="end">', getBalance(tokenId), " GWEI", '</text>',
                '<text x="95%" y="95%" class="base" dominant-baseline="middle" text-anchor="end">', getUsdBalance(tokenId), " USD", '</text>',
                '</svg>'
        );
        }
        return string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(svg)
            )    
        );
    }

    function getBalance(uint256 tokenId) private view returns (string memory) { 
        return (partnerVendorContract.getBalanceOfATokenId(tokenId)/10*10**9).toString();
    }

    function getUsdBalance(uint256 tokenId) private view returns (string memory) {
        return ((partnerVendorContract.getBalanceOfATokenId(tokenId)*(ETH_PRICE))).toString();// should be replace by code from oracle
    }

    function getDeadLine(uint256 tokenId) private view returns (string memory) {
       if (tokenIdMetadata[tokenId].deadLine > block.timestamp) {
        return (((tokenIdMetadata[tokenId].deadLine - block.timestamp) / (60 * 60 * 24))+1).toString() ;
        } else return "0";
    }

    function getReward(uint256 tokenId) private view returns (string memory) {
        return (tokenIdMetadata[tokenId].percent).toString();
    }

    function getUsed(uint256 tokenId) private view returns (string memory) {
        return tokenIdUsed[tokenId].toString();
    }

    function getUrl(uint256 tokenId) private view returns (string memory) {
        return tokenIdMetadata[tokenId].url;
    }

    function getMetadataRequired(uint256 tokenId) private view returns (string memory) {
        return tokenIdMetadata[tokenId].required.toString();
    }

    //@todo check visibilities and set them to external if pertinent
    function getTokenURI(uint256 tokenId) public view returns (string memory){
        bytes memory dataURI = abi.encodePacked(
            '{',
                '"name": "LoyaltEth Card #', tokenId.toString(), '",',
                '"description": "Here are your rewards",',
                '"image": "', generateCard(tokenId), '"',
            '}'
        );
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(dataURI)
            )
        );
    }

    function getTokenUsedById (uint256 tokenId) public view returns (uint8) {
        return tokenIdUsed[tokenId];
    }

    function getTokenRequired (uint256 tokenId) public view returns (uint8) {
        return tokenIdMetadata[tokenId].required;
    }

    function getTokenDeadLine (uint256 tokenId) public view returns (uint256) {
        return tokenIdMetadata[tokenId].deadLine;
    }

    function getTokenPercent (uint256 tokenId) public view returns (uint8) {
        return tokenIdMetadata[tokenId].percent;
    }

    function incTokenIdUsed (uint256 tokenId) public onlyPartner{
        require ( tokenIdUsed[tokenId] < tokenIdMetadata[tokenId].required , "cards is full");
        tokenIdUsed[tokenId] += 1;
    }

    function triggActiveToken (uint256 tokenId) public onlyPartner{
        require ( tokenIsActive[tokenId], "cards is inactive");
        tokenIsActive[tokenId] = false;
    }

    /*@params 
    * address _to eth address
    */
     function mint(address _to) external {
        _tokenIds.increment(); //start with id 1 
        uint256 newItemId = _tokenIds.current();
        _safeMint(_to, newItemId);
        tokenIsActive[newItemId] = true;
        uint256 deadLine = (block.timestamp) + (validity * 60 * 60 * 24);
        metadata = Metadata (url, required, validity, deadLine, percent);
        tokenIdMetadata[newItemId] = metadata;
        _setTokenURI(newItemId, getTokenURI(newItemId));
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    //removed ERC721URIStorage from the overides to avoid an error //
      function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

receive() external payable {}

}

