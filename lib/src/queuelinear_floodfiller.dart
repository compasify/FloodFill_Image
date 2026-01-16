//Original algorithm by J. Dunlap queuelinearfloodfill.aspx
//Java port by Owen Kaluza
//Android port by Darrin Smith (Standard Android)
//Flutter port by Garlen Javier

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;

extension ImageColor on Color {
  img.ColorInt16 toImageColor() {
    Uint8List bytes = Uint8List.fromList([
      this.r.toInt(),
      this.g.toInt(),
      this.b.toInt(),
      this.a.toInt(),
    ]);
    Int16List intList = Int16List.fromList(
      bytes.map((e) => e.toSigned(16)).toList(),
    );
    return img.ColorInt16.rgba(intList[0], intList[1], intList[2], intList[3]);
  }
}

class QueueLinearFloodFiller {
  img.Image? image;
  int _width = 0;
  int _height = 0;
  int _cachedWidth = -1;
  int _cachedHeight = -1;
  img.ColorInt16 _fillColor = img.ColorInt16.rgba(0, 0, 0, 0);
  int _tolerance = 8;
  int _brightnessThreshold = 128; // 0-255, pixels below this are "dark"
  img.ColorInt16 _startColor = img.ColorInt16.rgba(0, 0, 0, 0);
  List<bool>? _pixelsChecked;
  Queue<_FloodFillRange>? _ranges;

  QueueLinearFloodFiller(img.Image imgVal, Color newColor) {
    image = imgVal;
    _width = image!.width;
    _height = image!.height;
    setFillColor(newColor);
  }

  void resize(Size size) {
    if (_cachedWidth != size.width.toInt() ||
        _cachedHeight != size.height.toInt()) {
      //image = img.copyResize(image!, width: size.width.toInt(), height: size.height.toInt());
      _width = image!.width;
      _height = image!.height;
      _cachedWidth = _width;
      _cachedHeight = _height;
    }
  }

  void setTargetColor(Color targetColor) {
    _startColor = targetColor.toImageColor();
  }

  void setTolerance(int value) {
    _tolerance = value.clamp(0, 100);
  }

  void setBrightnessThreshold(int threshold) {
    _brightnessThreshold = threshold.clamp(0, 255);
  }

  int getBrightnessThreshold() => _brightnessThreshold;

  Color getFillColor() {
    return Color.fromARGB(
      _fillColor.a.toInt(),
      _fillColor.r.toInt(),
      _fillColor.g.toInt(),
      _fillColor.b.toInt(),
    );
  }

  void setFillColor(Color value) {
    _fillColor = value.toImageColor();
  }

  void _prepare() {
    // Called before starting flood-fill
    _pixelsChecked = List<bool>.filled(_width * _height, false);
    _ranges = Queue<_FloodFillRange>();
  }

  // Fills the specified point on the bitmap with the currently selected fill
  // color.
  // int x, int y: The starting coords for the fill
  Future<void> floodFill(int x, int y) async {
    // Setup
    _prepare();

    // ***Do first call to floodfill.
    _linearFill(x, y);

    // ***Call floodfill routine while floodfill _ranges still exist on the
    // queue
    _FloodFillRange range;

    while (_ranges!.length > 0) {
      // **Get Next Range Off the Queue
      range = _ranges!.removeFirst();

      // **Check Above and Below Each Pixel in the Floodfill Range
      int downPxIdx = (_width * (range.y + 1)) + range.startX;
      int upPxIdx = (_width * (range.y - 1)) + range.startX;
      int upY = range.y - 1; // so we can pass the y coord by ref
      int downY = range.y + 1;

      for (int i = range.startX; i <= range.endX; i++) {
        // *Start Fill Upwards
        // if we're not above the top of the bitmap and the pixel above
        // this one is within the color tolerance

        if (range.y > 0 && (!_pixelsChecked![upPxIdx]) && _checkPixel(i, upY)) {
          _linearFill(i, upY);
        }

        // *Start Fill Downwards
        // if we're not below the bottom of the bitmap and the pixel
        // below this one is within the color tolerance
        if (range.y < (_height - 1) &&
            (!_pixelsChecked![downPxIdx]) &&
            _checkPixel(i, downY)) {
          _linearFill(i, downY);
        }

        downPxIdx++;
        upPxIdx++;
      }
    }
  }

  // Finds the furthermost left and right boundaries of the fill area
  // on a given y coordinate, starting from a given x coordinate, filling as
  // it goes.
  // Adds the resulting horizontal range to the queue of floodfill _ranges,
  // to be processed in the main loop.
  //
  // int x, int y: The starting coords
  void _linearFill(int x, int y) {
    // ***Find Left Edge of Color Area
    int lFillLoc = x; // the location to check/fill on the left
    int pxIdx = (_width * y) + x;
    while (true) {
      // **fill with the color
      //pixels[pxIdx] = _fillColor;
      image?.setPixel(lFillLoc, y, _fillColor);

      // **indicate that this pixel has already been checked and filled
      _pixelsChecked![pxIdx] = true;

      // **de-increment
      lFillLoc--; // de-increment counter
      pxIdx--; // de-increment pixel index

      // **exit loop if we're at edge of bitmap or color area
      if (lFillLoc < 0 ||
          (_pixelsChecked![pxIdx]) ||
          !_checkPixel(lFillLoc, y)) {
        break;
      }
    }

    lFillLoc++;

    // ***Find Right Edge of Color Area
    int rFillLoc = x; // the location to check/fill on the left
    pxIdx = (_width * y) + x;

    while (true) {
      // **fill with the color
      image?.setPixel(rFillLoc, y, _fillColor);

      // **indicate that this pixel has already been checked and filled
      _pixelsChecked![pxIdx] = true;

      // **increment
      rFillLoc++; // increment counter
      pxIdx++; // increment pixel index

      // **exit loop if we're at edge of bitmap or color area
      if (rFillLoc >= _width ||
          _pixelsChecked![pxIdx] ||
          !_checkPixel(rFillLoc, y)) {
        break;
      }
    }

    rFillLoc--;
    // add range to queue
    _FloodFillRange r = new _FloodFillRange(lFillLoc, rFillLoc, y);
    _ranges?.add(r);
  }

  // Sees if a pixel is within the color tolerance range.
  // Also filters out dark pixels (below brightness threshold).
  bool _checkPixel(int x, int y) {
    img.Pixel pixelColor = image!.getPixelSafe(x, y);
    int red = pixelColor.getChannel(img.Channel.red).toInt();
    int green = pixelColor.getChannel(img.Channel.green).toInt();
    int blue = pixelColor.getChannel(img.Channel.blue).toInt();
    int alpha = pixelColor.getChannel(img.Channel.alpha).toInt();

    // Skip dark pixels - don't spread fill into dark areas (e.g., black outlines)
    int brightness = ((red + green + blue) / 3).round();
    if (brightness < _brightnessThreshold) return false;

    return (red >= (_startColor.r - _tolerance) &&
        red <= (_startColor.r + _tolerance) &&
        green >= (_startColor.g - _tolerance) &&
        green <= (_startColor.g + _tolerance) &&
        blue >= (_startColor.b - _tolerance) &&
        blue <= (_startColor.b + _tolerance) &&
        alpha >= (_startColor.a - _tolerance) &&
        alpha <= (_startColor.a + _tolerance));
  }
}

// Represents a linear range to be filled and branched from.
class _FloodFillRange {
  int startX = -1;
  int endX = -1;
  int y = -1;

  _FloodFillRange(int startX, int endX, int yPos) {
    this.startX = startX;
    this.endX = endX;
    this.y = yPos;
  }
}
