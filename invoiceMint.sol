// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (uint256);
}

contract NFTContract is ERC721URIStorage, Ownable {
    uint256 tokenId;
    IERC20 public token;

    constructor(address _token) ERC721("PBMCNFT", "PBMN") {
        token = IERC20(_token);
        allNfts.nfts.push();
    }

    struct NftDetails {
        address owner;
        address seller;
        uint256 price;
        uint256 tokens;
        bool isSold;
        bool isBurn;
    }
    struct Investor {
        uint256 deposit;
        uint256 withdraw;
    }
    struct AllNfts{
     NftDetails[] nfts;
    }
    AllNfts allNfts;
    mapping(address => uint256) public buyersDetail;
    mapping(address => Investor) public investorsDetail;
    mapping(uint256 => uint256) public idToIndex;

    function mint(string memory _tokenURI) external onlyOwner returns(uint){
        tokenId++;
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        return tokenId;
    }

    function depositCollateral(
        address seller,
        uint256 _tokenId,
        uint256 pbmcAmount,
        uint256 NFTPrice
    ) external {
        require(_tokenId <= tokenId && _tokenId != 0, "invalid token id");
        require(NFTPrice > 0, "nft value can not be zero");
        require(pbmcAmount > 0, "pbmc value can not be zero");
        require(idToIndex[_tokenId] == 0, "nft is already deposited");
        NftDetails memory nftDetails = NftDetails(
            msg.sender,
            seller,
            NFTPrice,
            pbmcAmount,
            false,
            false );
        allNfts.nfts.push(nftDetails);
        uint256 index = allNfts.nfts.length -1;
        idToIndex[_tokenId] = index ;
        token.transferFrom(msg.sender, address(this), pbmcAmount);
    }

    function sendTokenByBuyer(uint256 pbmcAmount) external {
        token.transferFrom(msg.sender, address(this), pbmcAmount);
        buyersDetail[msg.sender] += pbmcAmount;
    }

    function investorDeposit(uint256 _tokenId) external {
        require(_tokenId <= tokenId && _tokenId != 0, "invalid token id");
        uint256 index = idToIndex[_tokenId];
        NftDetails storage nftDetails = allNfts.nfts[index];
        require(nftDetails.isSold == false, "nft is already sold");
        require(nftDetails.price > 0, "wrong token id");
        token.transferFrom(msg.sender, address(this), nftDetails.price);
        nftDetails.owner = msg.sender;
        nftDetails.isSold = true;
    }

    function investorWithdraw(uint256 pbmcAmount, address _investorAddress)
        external
        onlyOwner
    {
        token.transfer(_investorAddress, pbmcAmount);
        investorsDetail[_investorAddress].withdraw += pbmcAmount;
    }

    function burnNft(uint256 _tokenId) external onlyOwner {
        uint index = idToIndex[_tokenId];
        require(_tokenId <= tokenId && _tokenId !=0, "invalid id");
        // require(nftDetails.isSold == false, "nft is already sold");
        _burn(_tokenId);
        allNfts.nfts[index].isBurn = true;
    }
    function getAllNfts() external view returns(AllNfts memory) {
        return allNfts;
    }
    
}
