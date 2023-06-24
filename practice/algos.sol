// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract sortArray {
    function sort(int256[5] memory array)
        public
        pure
        returns (int256[5] memory)
    {
        int256 temp;
        for (uint256 i = 0; i < array.length - 1; i++) {
            for (uint256 j = 0; j < array.length - i - 1; j++) {
                if (array[j] > array[j + 1]) {
                    temp = array[j];
                    array[j] = array[j + 1];
                    array[j + 1] = temp;
                }
            }
        }
        return array;
    }
}

contract CheckArrayLargestItem {
    function check(int256[5] calldata array) public pure returns (int256) {
        int256 dummyLarge = -999;
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] > dummyLarge) {
                dummyLarge = array[i];
            }
        }
        return dummyLarge;
    }
}

contract CheckArrayItem {
    function check(uint256[5] calldata array, uint256 item)
        public
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == item) {
                return true;
            }
        }
        return false;
    }
}

contract Concate {
    function concate(bytes memory str1, bytes memory str2)
        public
        pure
        returns (string memory)
    {
        bytes memory concatedString = bytes.concat(str1, str2);
        return string(concatedString);
    }
}

contract CheckHash {
    function check(bytes memory str1, bytes memory str2)
        public
        pure
        returns (bool)
    {
        if (
            keccak256(abi.encodePacked(str1)) ==
            keccak256(abi.encodePacked(str2))
        ) {
            return true;
        }
        return false;
    }
}
