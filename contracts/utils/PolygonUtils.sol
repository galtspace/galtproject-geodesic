/*
 * Copyright ©️ 2018 Galt•Project Society Construction and Terraforming Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka)
 *
 * Copyright ©️ 2018 Galt•Core Blockchain Company
 * (Founded by [Nikolai Popeka](https://github.com/npopeka) by
 * [Basic Agreement](ipfs/QmaCiXUmSrP16Gz8Jdzq6AJESY1EAANmmwha15uR3c1bsS)).
 */

pragma solidity ^0.5.13;

import "@galtproject/math/contracts/TrigonometryUtils.sol";
import "./LandUtils.sol";
import "./PointUtils.sol";
import "./SegmentUtils.sol";


library PolygonUtils {

  int256 public constant RADIUS = 6378137;
  int256 public constant PI = 3141592653589793300;

  struct LatLonData {
    mapping(uint => int256[2]) latLonByGeohash;
  }

  struct CoorsPolygon {
    int256[2][] points;
  }

  struct UtmPolygon {
    int256[3][] points;
  }

  function geohash5ToLatLonArr(LatLonData storage self, uint256 _geohash5) internal returns (int256[2] memory) {
    (int256 lat, int256 lon) = geohash5ToLatLon(self, _geohash5);
    return [lat, lon];
  }

  function geohash5ToLatLon(LatLonData storage self, uint256 _geohash5) internal returns (int256 lat, int256 lon) {
    if (self.latLonByGeohash[_geohash5][0] == 0) {
      self.latLonByGeohash[_geohash5] = LandUtils.geohash5ToLatLonArr(_geohash5);
    }

    return (self.latLonByGeohash[_geohash5][0], self.latLonByGeohash[_geohash5][1]);
  }

  function isInside(LatLonData storage self, uint _geohash5, uint256[] memory _polygon) public returns (bool) {
    (int256 x, int256 y) = geohash5ToLatLon(self, _geohash5);

    bool inside = false;
    uint256 j = _polygon.length - 1;

    for (uint256 i = 0; i < _polygon.length; i++) {
      (int256 xi, int256 yi) = geohash5ToLatLon(self, _polygon[i]);
      (int256 xj, int256 yj) = geohash5ToLatLon(self, _polygon[j]);

      bool intersect = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  function isInsideWithoutCache(
    uint256 _geohash5,
    uint256[] memory _polygon
  )
    public
    pure
    returns (bool)
  {
    (int256 x, int256 y) = LandUtils.geohash5ToLatLon(_geohash5);

    bool inside = false;
    uint256 j = _polygon.length - 1;

    for (uint256 i = 0; i < _polygon.length; i++) {
      (int256 xi, int256 yi) = LandUtils.geohash5ToLatLon(_polygon[i]);
      (int256 xj, int256 yj) = LandUtils.geohash5ToLatLon(_polygon[j]);

      bool intersect = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  function isInsideCoors(int256[2] memory _point, CoorsPolygon storage _polygon) internal view returns (bool) {
    bool inside = false;
    uint256 j = _polygon.points.length - 1;

    for (uint256 i = 0; i < _polygon.points.length; i++) {
      bool intersect = ((_polygon.points[i][1] > _point[1]) != (_polygon.points[j][1] > _point[1])) && (_point[0] < (_polygon.points[j][0] - _polygon.points[i][0]) * (_point[1] - _polygon.points[i][1]) / (_polygon.points[j][1] - _polygon.points[i][1]) + _polygon.points[i][0]);
      if (intersect) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  //TODO: test it
  function isClockwise(int[2] memory firstPoint, int[2] memory secondPoint, int[2] memory thirdPoint) internal pure returns (bool) {
    return (((secondPoint[0] - firstPoint[0]) * (secondPoint[1] + firstPoint[1])) +
    ((thirdPoint[0] - secondPoint[0]) * (thirdPoint[1] + secondPoint[1]))) > 0;
  }

  function getUtmArea(UtmPolygon memory _polygon) internal pure returns (uint result) {
    int area = 0;
    // Accumulates area in the loop
    uint j = _polygon.points.length - 1;
    // The last vertex is the 'previous' one to the first

    int scaleSum = 0;
    int firstScale;
    bool differentScales = false;
    int firstPointZone;
    for (uint i = 0; i < _polygon.points.length; i++) {
      area += ((_polygon.points[j][0] + _polygon.points[i][0]) * (_polygon.points[j][1] - _polygon.points[i][1])) / 1 ether;

      (,, int scale,, int zone,) = LandUtils.UtmUncompress(_polygon.points[i]);

      if (i == 0) {
        firstPointZone = zone;
        firstScale = (scale / int(10 ** 13)) * int(10 ** 13);
      } else {
        if (!differentScales) {
          differentScales = firstScale != (scale / int(10 ** 13)) * int(10 ** 13);
        }
      }

      require(zone == firstPointZone, "All points should belongs to same zone");

      scaleSum += scale;
      j = i;
      //j is previous vertex to i
    }
    if (area < 0) {
      area *= - 1;
    }

    if (differentScales) {
      // if scale is different with 0.00001 accuracy - apply scale
      result = (uint(area * 1 ether) / (uint(scaleSum / int(_polygon.points.length)) ** uint(2)) / 1 ether) / 2;
    } else {
      // else if scale the same - don't apply scale
      result = uint(area / 2);
    }
  }

  function rad(int angle) internal pure returns (int) {
    return angle * PI / 180 / 1 ether;
  }

  function isSelfIntersected(CoorsPolygon storage _polygon) public view returns (bool) {
    for (uint256 i = 0; i < _polygon.points.length; i++) {
      int256[2] storage iaPoint = _polygon.points[i];
      uint256 ibIndex = i == _polygon.points.length - 1 ? 0 : i + 1;
      int256[2] storage ibPoint = _polygon.points[ibIndex];

      for (uint256 k = 0; k < _polygon.points.length; k++) {
        int256[2] storage kaPoint = _polygon.points[k];
        uint256 kbIndex = k == _polygon.points.length - 1 ? 0 : k + 1;
        int256[2] storage kbPoint = _polygon.points[kbIndex];

        int256[2] memory intersectionPoint = SegmentUtils.findSegmentsIntersection([iaPoint, ibPoint], [kaPoint, kbPoint]);
        if (intersectionPoint[0] == 0 && intersectionPoint[1] == 0) {
          continue;
        }
        /* solium-disable-next-line */
        if (PointUtils.isEqual(intersectionPoint, iaPoint) || PointUtils.isEqual(intersectionPoint, ibPoint)
        || PointUtils.isEqual(intersectionPoint, kaPoint) || PointUtils.isEqual(intersectionPoint, kbPoint)) {
          continue;
        }
        return true;
      }
    }
    return false;
  }
}
