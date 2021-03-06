/*
 * Copyright ©️ 2018 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2018 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity ^0.5.13;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./utils/LandUtils.sol";
import "./utils/GeohashUtils.sol";
import "./utils/PolygonUtils.sol";
import "./interfaces/IGeodesic.sol";


//TODO: add Initializable
contract Geodesic is IGeodesic, Ownable {
  using SafeMath for uint256;

  LandUtils.LatLonData private latLonData;

  event ContourAreaCalculate(uint256[] contour, uint256 area);

  function cacheGeohashToLatLon(uint256 _geohash) public returns (int256[2] memory) {
    latLonData.latLonByGeohash[_geohash] = LandUtils.geohash5ToLatLonArr(_geohash);
    bytes32 pointHash = keccak256(abi.encode(latLonData.latLonByGeohash[_geohash]));
    latLonData.geohashByLatLonHash[pointHash][GeohashUtils.geohash5Precision(_geohash)] = _geohash;
    return latLonData.latLonByGeohash[_geohash];
  }

  function cacheGeohashListToLatLon(uint256[] memory _geohashList) public {
    for (uint i = 0; i < _geohashList.length; i++) {
      cacheGeohashToLatLon(_geohashList[i]);
    }
  }

  function cacheGeohashToLatLonAndUtm(uint256 _geohash) public returns (int256[3] memory) {
    latLonData.latLonByGeohash[_geohash] = LandUtils.geohash5ToLatLonArr(_geohash);
    bytes32 pointHash = keccak256(abi.encode(latLonData.latLonByGeohash[_geohash]));
    latLonData.geohashByLatLonHash[pointHash][GeohashUtils.geohash5Precision(_geohash)] = _geohash;

    latLonData.utmByLatLonHash[pointHash] = LandUtils.latLonToUtmCompressed(latLonData.latLonByGeohash[_geohash][0], latLonData.latLonByGeohash[_geohash][1]);

    latLonData.utmByGeohash[_geohash] = latLonData.utmByLatLonHash[pointHash];

    return latLonData.utmByGeohash[_geohash];
  }

  function cacheGeohashListToLatLonAndUtm(uint256[] memory _geohashList) public {
    for (uint i = 0; i < _geohashList.length; i++) {
      cacheGeohashToLatLonAndUtm(_geohashList[i]);
    }
  }

  function cacheLatLonToGeohash(int256[2] memory point, uint8 precision) public returns (uint256) {
    bytes32 pointHash = keccak256(abi.encode(point));
    latLonData.geohashByLatLonHash[pointHash][precision] = LandUtils.latLonToGeohash5(point[0], point[1], precision);
    return latLonData.geohashByLatLonHash[pointHash][precision];
  }

  function cacheLatLonListToGeohash(int256[2][] memory _pointList, uint8 precision) public {
    for (uint i = 0; i < _pointList.length; i++) {
      cacheLatLonToGeohash(_pointList[i], precision);
    }
  }

  function cacheLatLonToUtm(int256[2] memory point) public returns (int256[3] memory) {
    bytes32 pointHash = keccak256(abi.encode(point));
    latLonData.utmByLatLonHash[pointHash] = LandUtils.latLonToUtmCompressed(point[0], point[1]);
    return latLonData.utmByLatLonHash[pointHash];
  }

  function cacheLatLonListToUtm(int256[2][] memory _pointList) public {
    for (uint i = 0; i < _pointList.length; i++) {
      cacheLatLonToUtm(_pointList[i]);
    }
  }

  function calculateContourArea(uint256[] calldata contour) external returns (uint256 area) {
    PolygonUtils.UtmPolygon memory p;
    p.points = new int256[3][](contour.length);

    for (uint i = 0; i < contour.length; i++) {
      if (latLonData.utmByGeohash[contour[i]][0] != 0) {
        p.points[i] = latLonData.utmByGeohash[contour[i]];
      } else {
        p.points[i] = cacheGeohashToLatLonAndUtm(contour[i]);
      }
    }
    area = PolygonUtils.getUtmArea(p);
    emit ContourAreaCalculate(contour, area);
  }

  function getCachedGeohashByLatLon(int256[2] memory point, uint8 precision) public view returns (uint256) {
    bytes32 pointHash = keccak256(abi.encode(point));
    return latLonData.geohashByLatLonHash[pointHash][precision];
  }

  function getCachedLatLonByGeohash(uint256 _geohash) public view returns (int256[2] memory) {
    return latLonData.latLonByGeohash[_geohash];
  }

  function getCachedUtmByGeohash(uint256 _geohash) public view returns (int256[3] memory) {
    return latLonData.utmByGeohash[_geohash];
  }

  function getCachedUtmByLatLon(int256[2] memory point) public view returns (int256[3] memory) {
    bytes32 pointHash = keccak256(abi.encode(point));
    return latLonData.utmByLatLonHash[pointHash];
  }

  function getContourArea(uint256[] calldata contour) external view returns (uint256 area) {
    PolygonUtils.UtmPolygon memory p;
    p.points = new int256[3][](contour.length);

    for (uint i = 0; i < contour.length; i++) {
      if (latLonData.utmByGeohash[contour[i]][0] != 0) {
        p.points[i] = latLonData.utmByGeohash[contour[i]];
      } else {
        revert("Geohashes should be cached");
      }
    }
    area = PolygonUtils.getUtmArea(p);
  }

  function getNotCachedGeohashes(uint256[] memory _geohashList) public view returns (uint256[] memory) {
    uint256[] memory notCachedGeohashes = new uint256[](_geohashList.length);
    uint resultLength = 0;

    for (uint i = 0; i < _geohashList.length; i++) {
      if (latLonData.utmByGeohash[_geohashList[i]][0] != 0) {
        continue;
      }

      notCachedGeohashes[resultLength] = _geohashList[i];
      resultLength++;
    }

    if (resultLength == notCachedGeohashes.length) {
      return notCachedGeohashes;
    }

    uint256[] memory resultGeohashes = new uint256[](resultLength);

    for (uint i = 0; i < resultGeohashes.length; i++) {
      resultGeohashes[i] = notCachedGeohashes[i];
    }
    return resultGeohashes;
  }
}
