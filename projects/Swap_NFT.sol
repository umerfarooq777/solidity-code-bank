// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
// pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; // in the upgradable contracts we need to remove constructor and replace that with Initializer
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract Swap_NFT is
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    ERC721HolderUpgradeable,
    ERC1155HolderUpgradeable
{
    using SafeMathUpgradeable for uint256;

    ERC721NFTInfoForSwap[] internal availableItemsFor721;
    ERC1155NFTInfoForSwap[] internal availableItemsFor1155;
    uint256[] internal withdrawnIndexesFor721;
    uint256[] internal withdrawnIndexesFor1155;
    uint256 public fundedNftCountFor721;
    uint256 public fundedNftCountFor1155;
    uint256 vacantWithdrawnIndexesLenFor721;
    uint256 vacantWithdrawnIndexesLenFor1155;
    bytes32 internal securityHash;
    bytes4 constant ERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes4 constant ERC721_INTERFACE_ID = 0x80ac58cd;
    struct ERC721NFTInfoForSwap {
        address nftContractAddress;
        uint256 tokenId;
        address owner;
        bool withdrawn;
    }
    struct ERC1155NFTInfoForSwap {
        address nftContractAddress;
        uint256 amount;
        uint256 tokenId;
        address owner;
        bool withdrawn;
    }

    function initialize(bytes32 securityHash_) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        securityHash = securityHash_;
    }

    function _authorizeUpgrade(address _newImplementation)
        internal
        override
        onlyOwner
    {}

    function getERC721Len() public view returns (uint256) {
        return availableItemsFor721.length;
    }

    function getERC1155Len() public view returns (uint256) {
        return availableItemsFor1155.length;
    }

    function getERC721NFTCount() public view returns (uint256) {
        return availableItemsFor721.length - (withdrawnIndexesFor721.length - vacantWithdrawnIndexesLenFor721);
    }

    function getERC1155NFTCount() public view returns (uint256) {
        return availableItemsFor1155.length - (withdrawnIndexesFor1155.length - vacantWithdrawnIndexesLenFor1155);
    }

    function changeSecurityHash(bytes32 newSecurityHash)
        external
        onlyOwner
        returns (bool)
    {
        securityHash = newSecurityHash;
        return true;
    }

    function checkInterface(address nftContractAddress, bytes4 interfaceId)
        internal
        view
        returns (bool)
    {
        return IERC165(nftContractAddress).supportsInterface(interfaceId);
    }

    modifier listingRequirements(
        address nftContractAddress,
        address biddersAddress,
        uint256 tokenId,
        uint256 amount
    ) {
        if (checkInterface(nftContractAddress, ERC721_INTERFACE_ID)) {
            require(
                ERC721(nftContractAddress).ownerOf(tokenId) == biddersAddress,
                "Owner not Bidder."
            );
        } else {
            require(
                ERC1155(nftContractAddress).balanceOf(
                    biddersAddress,
                    tokenId
                ) >= amount,
                "Owner not Bidder Or Bidder does not have enough NFTs."
            );
        }
        require(
            ERC721(nftContractAddress).isApprovedForAll(
                biddersAddress,
                address(this)
            ),
            "Token not Approved From Bidder."
        );
        _;
    }

    function _removeSwapListing(uint256 swapId, bool isErc721) internal {
        if (isErc721) {
            if (
                withdrawnIndexesFor721.length == 0 ||
                vacantWithdrawnIndexesLenFor721 == 0
            ) {
                withdrawnIndexesFor721.push(swapId);
            } else {
                withdrawnIndexesFor721[
                    withdrawnIndexesFor721.length.sub(
                        vacantWithdrawnIndexesLenFor721
                    )
                ] = swapId; // 5 - 4
                vacantWithdrawnIndexesLenFor721--;
            }
            fundedNftCountFor721--;
        } else {
            if (
                withdrawnIndexesFor1155.length == 0 ||
                vacantWithdrawnIndexesLenFor1155 == 0
            ) {
                withdrawnIndexesFor1155.push(swapId);
            } else {
                withdrawnIndexesFor1155[
                    withdrawnIndexesFor1155.length.sub(
                        vacantWithdrawnIndexesLenFor1155
                    )
                ] = swapId; // 5 - 4
                vacantWithdrawnIndexesLenFor1155--;
            }
            fundedNftCountFor1155--;
        }
    }

    function getSwapId(bool isErc721) internal returns (uint256) {
        uint256 swapId;
        if (isErc721) {
            if (
                (withdrawnIndexesFor721.length).sub(
                    vacantWithdrawnIndexesLenFor721
                ) > 0
            ) {
                swapId = withdrawnIndexesFor721[
                    (
                        (withdrawnIndexesFor721.length).sub(
                            vacantWithdrawnIndexesLenFor721
                        )
                    ).sub(1)
                ];
                delete withdrawnIndexesFor721[
                    (
                        (withdrawnIndexesFor721.length).sub(
                            vacantWithdrawnIndexesLenFor721
                        )
                    ).sub(1)
                ];
                vacantWithdrawnIndexesLenFor721++;
            } else {
                swapId = getERC721Len();
            }
        } else {
            if (
                (withdrawnIndexesFor1155.length).sub(
                    vacantWithdrawnIndexesLenFor1155
                ) > 0
            ) {
                swapId = withdrawnIndexesFor1155[
                    (
                        (withdrawnIndexesFor1155.length).sub(
                            vacantWithdrawnIndexesLenFor1155
                        )
                    ).sub(1)
                ];
                delete withdrawnIndexesFor1155[
                    (
                        (withdrawnIndexesFor1155.length).sub(
                            vacantWithdrawnIndexesLenFor1155
                        )
                    ).sub(1)
                ];
                vacantWithdrawnIndexesLenFor1155++;
            } else {
                swapId = getERC1155Len();
            }
        }
        return swapId;
    }

    event swaped(bool swaped, address nftContractAddress, uint256 tokenId, address prevOwner);
    event orderPlaced(
        address nftContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 orderId
    );

    event fundNft(address fundedNftOwner, uint256 swapId);
    uint256[] public fundedNftiDTEST;

    function fundNFTForRandomSwap(
        address nftContractAddress,
        uint256 tokenId,
        uint256 amount
    ) public {
        bool isErc721 = checkInterface(nftContractAddress, ERC721_INTERFACE_ID);
        // bool isErc721 = true;
        uint256 swapId = getSwapId(isErc721);
        fundedNftiDTEST.push(swapId);
        uint256 arrayLen;
        // uint256 swapId = 0;
        require(
            ERC721(nftContractAddress).isApprovedForAll(
                msg.sender,
                address(this)
            ),
            "NFT not Approved."
        );
        if (isErc721) {
            ERC721(nftContractAddress).safeTransferFrom(
                msg.sender,
                address(this),
                tokenId
            );
            arrayLen = getERC721Len();
            if (swapId == arrayLen) {
            availableItemsFor721.push(ERC721NFTInfoForSwap(
                nftContractAddress,
                tokenId,
                msg.sender,
                false
            ));
            } else {
                availableItemsFor721[swapId] = ERC721NFTInfoForSwap(
                nftContractAddress,
                tokenId,
                msg.sender,
                false
            );
            }
            fundedNftCountFor721++;
        } else {
            ERC1155(nftContractAddress).safeTransferFrom(
                msg.sender,
                address(this),
                tokenId,
                amount,
                ""
            );
            arrayLen = getERC1155Len();
            if (swapId == arrayLen) {
            availableItemsFor1155.push(ERC1155NFTInfoForSwap(
                nftContractAddress,
                amount,
                tokenId,
                msg.sender,
                false
            ));
            } else {
            availableItemsFor1155[swapId] = ERC1155NFTInfoForSwap(
                nftContractAddress,
                amount,
                tokenId,
                msg.sender,
                false
            );
            }
            fundedNftCountFor1155++;
        }
        emit fundNft(msg.sender , swapId);
    }

    function withdrawNFT(uint256 swapId, address nftContractAddress) public {
        bool isErc721 = checkInterface(nftContractAddress, ERC721_INTERFACE_ID);
        if (isErc721) {
            require(
                availableItemsFor721[swapId].owner == msg.sender,
                "Not Owner."
            );
            require(
                availableItemsFor721[swapId].withdrawn == false,
                "Already Withdrawn"
            );
            availableItemsFor721[swapId].withdrawn = true;
            ERC721(nftContractAddress).safeTransferFrom(
                address(this),
                msg.sender,
                availableItemsFor721[swapId].tokenId
            );
        } else {
            require(
                availableItemsFor1155[swapId].owner == msg.sender,
                "Not Owner."
            );
            require(
                availableItemsFor1155[swapId].withdrawn == false,
                "Already Withdrawn"
            );
            availableItemsFor1155[swapId].withdrawn = true;
            ERC1155(nftContractAddress).safeTransferFrom(
                address(this),
                msg.sender,
                availableItemsFor1155[swapId].tokenId,
                availableItemsFor1155[swapId].amount,
                ""
            );
        }
        _removeSwapListing(swapId, isErc721);
    }

    function SwapNFTs(
        address nftContractAddress,
        uint256 tokenId,
        uint256 amount,
        // random if its a random swap, else 0;
        uint256 swapId
    ) external {
        bool isErc721 = checkInterface(nftContractAddress, ERC721_INTERFACE_ID);
        require(
            ERC721(nftContractAddress).isApprovedForAll(
                msg.sender,
                address(this)
            ),
            "NFT not Approved."
        );
        if (isErc721) {
            require(fundedNftCountFor721 > 0, "Not Enough NFTS to swap.");
            ERC721 Contract = ERC721(nftContractAddress);
            require(
                Contract.ownerOf(tokenId) == msg.sender,
                "Caller Not Owner."
            );

            Contract.safeTransferFrom(msg.sender, address(this), tokenId);
            ERC721NFTInfoForSwap memory nft = availableItemsFor721[swapId];
            Contract.safeTransferFrom(address(this), nft.owner, tokenId);
            ERC721(nft.nftContractAddress).safeTransferFrom(
                address(this),
                msg.sender,
                nft.tokenId
            );
        emit swaped(true, nft.nftContractAddress, nft.tokenId, nft.owner);

        } else {
            require(fundedNftCountFor1155 > 0, "Not Enough NFTS to swap.");
            ERC1155 Contract = ERC1155(nftContractAddress);
            require(
                ERC1155(nftContractAddress).balanceOf(msg.sender, tokenId) >=
                    amount,
                "Caller Not Owner."
            );
            Contract.safeTransferFrom(
                msg.sender,
                address(this),
                tokenId,
                amount,
                ""
            );
            ERC1155NFTInfoForSwap memory nft = availableItemsFor1155[swapId];
            Contract.safeTransferFrom(address(this), nft.owner, tokenId, amount, "");
            ERC1155(nft.nftContractAddress).safeTransferFrom(
                address(this),
                msg.sender,
                nft.amount,
                nft.tokenId,
                ""
            );
        emit swaped(true, nft.nftContractAddress, nft.tokenId, nft.owner);
        }
        _removeSwapListing(swapId, isErc721);
    }

    function ExecuteSwapOrder(
        address nftContractAddress,
        address nftContractAddressToSwapWith,
        address makerAddress,
        address takerAddress,
        uint256 tokenId,
        uint256 tokenIdToSwapWith,
        uint256 amount,
        uint256 amountToSwapWith,
        bytes32 securityHash_
    )
        public
        listingRequirements(
            nftContractAddressToSwapWith,
            takerAddress,
            tokenIdToSwapWith,
            amountToSwapWith
        )
    {
        if (securityHash != securityHash_) {
            revert();
        }
        require(
            nftContractAddress == nftContractAddressToSwapWith,
            "Contract Address must be same."
        );
        require(makerAddress == msg.sender, "Caller not Maker.");
        bool isErc721 = checkInterface(
            nftContractAddressToSwapWith,
            ERC721_INTERFACE_ID
        );
        if (isErc721) {
            require(
                ERC721(nftContractAddress).ownerOf(tokenId) == makerAddress,
                "No NFT to transfer."
            );
            require(
                ERC721(nftContractAddressToSwapWith).ownerOf(
                    tokenIdToSwapWith
                ) == takerAddress,
                "Taker does not have the NFT"
            );
            ERC721(nftContractAddress).safeTransferFrom(
                makerAddress,
                address(this),
                tokenId
            );
            ERC721(nftContractAddressToSwapWith).safeTransferFrom(
                takerAddress,
                address(this),
                tokenIdToSwapWith
            );
            ERC721(nftContractAddressToSwapWith).safeTransferFrom(
                address(this),
                makerAddress,
                tokenIdToSwapWith
            );
            ERC721(nftContractAddress).safeTransferFrom(
                address(this),
                takerAddress,
                tokenId
            );
        } else {
            require(
                ERC1155(nftContractAddress).balanceOf(makerAddress, tokenId) >=
                    amount,
                "No NFT to transfer."
            );
            require(
                ERC1155(nftContractAddressToSwapWith).balanceOf(
                    takerAddress,
                    tokenIdToSwapWith
                ) >= amountToSwapWith,
                "Taker does not have the NFT"
            );
            ERC1155(nftContractAddress).safeTransferFrom(
                makerAddress,
                address(this),
                tokenId,
                amount,
                ""
            );
            ERC1155(nftContractAddressToSwapWith).safeTransferFrom(
                takerAddress,
                address(this),
                tokenIdToSwapWith,
                amountToSwapWith,
                ""
            );
            ERC1155(nftContractAddress).safeTransferFrom(
                address(this),
                takerAddress,
                tokenId,
                amount,
                ""
            );
            ERC1155(nftContractAddressToSwapWith).safeTransferFrom(
                address(this),
                msg.sender,
                tokenIdToSwapWith,
                amountToSwapWith,
                ""
            );
        }
        emit swaped(true, nftContractAddressToSwapWith, tokenIdToSwapWith, takerAddress);
    }
}

// 0xFAD905077AC1C3dCc473e05a06fa6dE4e65C5B1b //main address
// hash: 0x3fced41f7621831f9b0556f45cfacf4d9d4b2794bfa4d69e4f370d4fd83e60b3
