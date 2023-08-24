// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.16;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IOptionToken is IERC721 {
    function nextId() external view returns (uint256);
}