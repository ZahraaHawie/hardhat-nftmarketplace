// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
//(G)
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error PriceMustBeAboveZero();
error NotApprovedForMarketplace();
error AlreadyListed(address nftAddress, uint256 tokenId);
error NotOwner();
error NotListed(address nftAddress, uint256 tokenId);
error PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NoProceeds();

contract NftMarketplace is ReentrancyGuard {
    struct Listing {
        uint256 price;
        address seller;
    }
    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemCanceled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    //NFT Contract address -> NFT TokenID -> Listing
    mapping(address => mapping(uint256 => Listing)) private s_listings;

    //(E)
    //Seller address => Amount Earned
    mapping(address => uint256) private s_proceeds;

    //(C):
    modifier notListed(
        address nftAddress,
        uint256 tokenId,
        address owner
    ) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }
    //(D)
    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NotListed(nftAddress, tokenId);
        }
        _;
    }

    //Main Functions

    /*
     * @notice Method for listing NFT
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     * @param price sale price for each item
     */

    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    )
        external
        notListed(nftAddress, tokenId, msg.sender)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        if (price <= 0) {
            revert PriceMustBeAboveZero();
        }
        //(A)
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            //if we're not approved
            revert NotApprovedForMarketplace();
        }
        //(B)
        s_listings[nftAddress][tokenId] = Listing(price, msg.sender); //msg.sender:Seller(the one who is listing the item)
        emit ItemListed(msg.sender, nftAddress, tokenId, price);
    }

    //(D)
    /*
     * @notice Method for buying listing
     * @notice The owner of an NFT could unapprove the marketplace,
     * which would cause this function to fail
     * Ideally you'd also have a `createOffer` functionality.
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     */
    function buyItem(address nftAddress, uint256 tokenId)
        external
        payable
        //(G)
        nonReentrant
        isListed(nftAddress, tokenId)
    {
        Listing memory listedItem = s_listings[nftAddress][tokenId];
        if (msg.value < listedItem.price) {
            revert PriceNotMet(nftAddress, tokenId, listedItem.price);
        }
        s_proceeds[listedItem.seller] =
            s_proceeds[listedItem.seller] +
            msg.value;
        delete (s_listings[nftAddress][tokenId]);
        IERC721(nftAddress).safeTransferFrom(
            listedItem.seller,
            msg.sender,
            tokenId
        );
        //(F)
        emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
    }

    /*
     * @notice Method for cancelling listing
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     */

    function cancelListing(address nftAddress, uint256 tokenId)
        external
        isOwner(nftAddress, tokenId, msg.sender) //to make sure only the owner can cancel
        isListed(nftAddress, tokenId)
    {
        delete (s_listings[nftAddress][tokenId]);
        emit ItemCanceled(msg.sender, nftAddress, tokenId);
    }

    /*
     * @notice Method for updating listing
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     * @param newPrice Price in Wei of the item
     */

    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    )
        external
        isListed(nftAddress, tokenId)
        nonReentrant
        isOwner(nftAddress, tokenId, msg.sender)
    {
        s_listings[nftAddress][tokenId].price = newPrice;
        emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
    }

    /*
     * @notice Method for withdrawing proceeds from sales
     */

    function withdrawProceeds() external {
        uint256 proceeds = s_proceeds[msg.sender];
        if (proceeds <= 0) {
            revert NoProceeds();
        }
        s_proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        require(success, "Transfer failed");
    }

    //getter functions

    function getListing(address nftAddress, uint256 tokenId)
        external
        view
        returns (Listing memory)
    {
        return s_listings[nftAddress][tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}

/*  

Step 1 : 
A listing involves getting your NFT seen on the marketplace 
To list it, we could do one of these 2 ways: 
    1. Send the NFT to the contract. Transfer -> Contract "Hold" the NFT.
    2. (Gas Expensive) Marketplace will own NFT. Owner can still hold their NFT, 
       and give the marketplace approval to sell the NFT form them. 
       The owners of the entity could withdraw approval at any time 
       and the marketplace wouldn't be able to sell it anymore.

        We will use the second one. People still will have ownership of their NFTs, 
        and the marketplace will just have approval to actually swap and 
        sell their NFT once the prices are met.

(A): We have to call getApproved(_tokenId) fct from ERC721 to make sure that the marketplace
is approved to work with the NFT. So we need to import ERC721 Interface.

(B): we're probably going to want to have some type of data structure 
to list all these NFTs: Array or mapping or ??  
Mapping is better than array since when someone wants to buy an item, we are gonna have
to traverse through the array.. We have to put mapping as state variable above. 

(C): We want to make sure we only list NFTs that haven't already been listed.
Add modifier : Not listed
Add other modifier : owner of the nft 

(D): "external" because only people outside of this contract are going to call buyItem.
"Payable": people can spend ETH or any other currency.
To actually buy these prices we want "ChainlinkPriceFeeds" for listing. 
Use chainlink pricefeeds to convert the priceof these tokens into 
how much they actually cost. 

In ListItem function:
Challenge: Have this contract accept payment in a subset of tokens
Hint: Use price feeds to convert the price of the tokens 
between each other. 

Now, inisde BuyItem function: we have to make sure that item is listed before buying. 
Add modifier called: isListed

(E): 
We want to create another data structure called proceeds 
where we keep track of how much money people have earned selling their NFTs.
(mapping)
So when somebody buys an item, is will update their proceeds.

(F): Notice something here, we don't just send the seller the money. 
Now why is that? Well, solidity has this concept called pull over push. 
And it's considered a best practice when working with solidity, 
you want to shift the risk associated with transferring ether to the user. 

So instead of sending the money to the user, this is what we don't want to do
-We want to have them withdraw the money.

We don't want to send the money directly.. 
We want to create his proceeds data structure 
& we can have them withdraw from it later.

We use "SafeTransformFrom" 
Check to make sure the NFT was transferred.. 

(G):

Reentrancy Attacks: 
In this BuyItem function we have set this up in a way that is safe from something 
called "Reentrancy Attack". Check Reentrant Vulnerable contract. 

import from openzeppelin.. ReentrancyGuard and then add the modifier in
any function we are nervous about it.


Check out https://github.com/Fantom-foundation/Artion-Contracts/blob/5c90d2bc0401af6fb5abf35b860b762b31dfee02/contracts/FantomMarketplace.sol
For a full decentralized nft marketplace

*/
