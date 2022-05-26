// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ERC20Wrapper.sol";
import "./IShareToken.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@opengsn/contracts/src/BaseRelayRecipient.sol";

interface IDAILikePermit {
    function nonces(address) external returns (uint256);

    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

interface IMarket {
    function getNumTicks() external returns (uint256);
}


contract AugurFoundry  is ERC1155Receiver, BaseRelayRecipient {
    using SafeMath for uint256;
    IShareToken public immutable shareToken;
    IERC20 public immutable cash;
    address public immutable augur;


    mapping(uint256 => address) public wrappers;

    event WrapperCreated(uint256 indexed tokenId, address tokenAddress);

    constructor(
        IShareToken _shareToken, //mockshare
        IERC20 _cash,//Mockcash
        address _augur,//erc20
        address _trustedForwarder
    ){
        cash = _cash;
        shareToken = _shareToken;
        augur = _augur;
        _setTrustedForwarder(_trustedForwarder);
        _cash.approve(_augur, (2 ** 256 - 1));
    }

    function approveCashtoAugur() external {
        cash.approve(augur, 2 ** 256 - 1);
    }

    function getTrustedForwarder() external view returns (address) {
        return trustedForwarder();
    }

    function versionRecipient() external pure override returns (string memory) {
        return '1';
    }

    function newERC20Wrapper(
        uint256 _tokenId,
        string memory _name,
        string memory _symbol
        // uint8 _decimals
    ) public {
        require(wrappers[_tokenId] == address(0), 'Wrapper already created');
        ERC20Wrapper erc20Wrapper =
            new ERC20Wrapper(
                address(this),
                shareToken,
                cash,
                _tokenId,
                _name,
                _symbol
                // _decimals
            );
        wrappers[_tokenId] = address(erc20Wrapper);
        emit WrapperCreated(_tokenId, address(erc20Wrapper));
    }

    function newERC20Wrappers(
        uint256[] memory _tokenIds,
        string[] memory _names,
        string[] memory _symbols
    ) public {
        require(
            _tokenIds.length == _names.length &&
                _tokenIds.length == _symbols.length
        );
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            newERC20Wrapper(_tokenIds[i], _names[i], _symbols[i]);
        }
    }



    function wrapTokens(
        uint256 _tokenId,
        address _account,
        uint256 _amount
    ) public {
        ERC20Wrapper erc20Wrapper = ERC20Wrapper(wrappers[_tokenId]);
        shareToken.safeTransferFrom(
            msg.sender,
            address(erc20Wrapper),
            _tokenId,
            _amount,
            ''
        );
        erc20Wrapper.wrapTokens(_account, _amount);
    }

    function wrapMultipleTokens(
        uint256[] memory _tokenIds,
        address _account,
        uint256[] memory _amounts
    ) public {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            wrapTokens(_tokenIds[i], _account, _amounts[i]);
        }
    }

    function unWrapTokens(
        uint256 _tokenId,
        uint256 _amount,
        address _recipient
    ) public {
        ERC20Wrapper erc20Wrapper = ERC20Wrapper(wrappers[_tokenId]);
        erc20Wrapper.unWrapTokens(msg.sender, _amount, _recipient);
    }

    function unWrapMultipleTokens(
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        address _recipient
    ) public {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            unWrapTokens(_tokenIds[i], _amounts[i], _recipient);
        }
    }

    function permit(
        uint256 _expiry,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal {
        uint256 nonce = IDAILikePermit(address(cash)).nonces(msg.sender);
        IDAILikePermit(address(cash)).permit(
            msg.sender,
            address(this),
            nonce,
            _expiry,
            true,
            _v,
            _r,
            _s
        );
    }//



    function buyCompleteSets(
        address _market,
        address _account,
        uint256 _amount
    ) public returns (bool) {
        uint256 numTicks = IMarket(_market).getNumTicks();
        require(
            cash.transferFrom(
                msg.sender,
                address(this),
                _amount.mul(numTicks)
            )
        );
        require(shareToken.buyCompleteSets(_market, _account, _amount));
        return true;//added
    }

    
    function permitAndBuyCompleteSets(
        address _market,
        address _account,
        uint256 _amount,
        uint256 _expiry,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (bool) {
        permit(_expiry, _v, _r, _s);
        buyCompleteSets(_market, _account, _amount);
        return true;//added
    }

    function claim(uint256 _tokenId) external {
        ERC20Wrapper erc20Wrapper = ERC20Wrapper(wrappers[_tokenId]);
        erc20Wrapper.claim(msg.sender);
    }


    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override  pure returns (bytes4) {
        operator;
        from;
        id;
        value;
        data;
        return (
            bytes4(
                keccak256(
                    'onERC1155Received(address,address,uint256,uint256,bytes)'
                )
            )
        );
    }


    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override pure returns (bytes4) {
        operator;
        from;
        ids;
        values;
        data;
        return
            bytes4(
                keccak256(
                    'onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)'
                )
            );
    }

}