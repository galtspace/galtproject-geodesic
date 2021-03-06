/*
 * Copyright ©️ 2018 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2018 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity ^0.5.13;


import "@galtproject/libs/contracts/collections/RedBlackTree.sol";
import "../utils/SegmentUtils.sol";


library SegmentRedBlackTree {
  using RedBlackTree for RedBlackTree.Tree;

  struct SegmentsTree {
    RedBlackTree.Tree tree;
    SegmentUtils.Sweepline sweepline;
    mapping(uint => int256[2][2]) values;
  }

  uint internal constant ZERO = 0;

  function find(SegmentsTree storage segments, int256[2][2] memory value) public view returns (uint) {
    uint _key = segments.tree.root;
    while (_key != ZERO) {
      int8 compareResult = SegmentUtils.compareSegments(segments.sweepline, value, segments.values[_key]);
      if (compareResult == 0) {
        return _key;
      }
      if (compareResult < 0) {
        _key = segments.tree.items[_key].left;
      } else {
        _key = segments.tree.items[_key].right;
      }
    }
    return ZERO;
  }

  function insert(SegmentsTree storage segments, uint key, int256[2][2] memory value) public {
    uint y = ZERO;
    uint x = segments.tree.root;
    while (x != ZERO) {
      y = x;
      int8 compareResult = SegmentUtils.compareSegments(segments.sweepline, value, segments.values[x]);
      if (compareResult < 0) {
        x = segments.tree.items[x].left;
      } else {
        if (compareResult == 0) {
          return;
        }
        x = segments.tree.items[x].right;
      }
    }
    segments.tree.items[key] = RedBlackTree.Item(y, ZERO, ZERO, true);
    segments.values[key] = value;

    if (y == ZERO) {
      segments.tree.root = key;
    } else if (SegmentUtils.compareSegments(segments.sweepline, segments.values[key], segments.values[y]) < 0) {
      segments.tree.items[y].left = key;
    } else {
      segments.tree.items[y].right = key;
    }
    segments.tree.insertFixup(key);
    segments.tree.inserted++;
  }

  function setSweeplineX(SegmentsTree storage segments, int256 x) public {
    segments.sweepline.x = x;
  }

  function setSweeplinePosition(SegmentsTree storage segments, SegmentUtils.Position position) public {
    segments.sweepline.position = position;
  }

  function getNewId(SegmentsTree storage segments) public view returns(uint256) {
    return segments.tree.inserted + 1;
  }

  function pop(SegmentsTree storage segments) public returns(uint256 id, int256[2][2] memory value) {
    id = segments.tree.pop();
    value = segments.values[id];
  }
}
