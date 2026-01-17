//Scanline flood fill algorithm with span tracking
//Based on prototype implementation with optimizations
//Preserves QueueLinearFloodFiller API for backward compatibility

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;
import 'queuelinear_floodfiller.dart' show ImageColor;

enum FillMode {
  tolerance, // Color tolerance-based matching (original behavior)
  brightness // Brightness-based boundary detection (prototype behavior)
}

class ScanlineFloodFiller {
  img.Image? image;
  int _width = 0;
  int _height = 0;
  int _cachedWidth = -1;
  int _cachedHeight = -1;

  // Color settings
  img.ColorInt16 _fillColor = img.ColorInt16.rgba(0, 0, 0, 0);
  img.ColorInt16 _startColor = img.ColorInt16.rgba(0, 0, 0, 0);

  // Mode settings
  FillMode _mode = FillMode.brightness;
  int _tolerance = 8;
  int _brightnessThreshold = 80;

  // Fill state
  Uint8List? _visited;
  List<int> _stack = [];

  ScanlineFloodFiller(img.Image imgVal, Color newColor) {
    image = imgVal;
    _width = image!.width;
    _height = image!.height;
    setFillColor(newColor);
  }

  void resize(Size size) {
    if (_cachedWidth != size.width.toInt() ||
        _cachedHeight != size.height.toInt()) {
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

  // Mode selection methods
  void setMode(FillMode mode) {
    _mode = mode;
  }

  /// Convenience: set brightness mode with threshold
  void useBrightnessMode(int threshold) {
    _mode = FillMode.brightness;
    _brightnessThreshold = threshold.clamp(0, 255);
  }

  /// Convenience: set tolerance mode
  void useToleranceMode(int tolerance) {
    _mode = FillMode.tolerance;
    _tolerance = tolerance.clamp(0, 100);
  }

  /// Boundary detection using luminance formula (weighted average)
  /// Matches prototype implementation
  bool _isBoundary(int x, int y) {
    if (x < 0 || x >= _width || y < 0 || y >= _height) return true;

    final pixel = image!.getPixelSafe(x, y);
    final r = pixel.getChannel(img.Channel.red).toInt();
    final g = pixel.getChannel(img.Channel.green).toInt();
    final b = pixel.getChannel(img.Channel.blue).toInt();
    final a = pixel.getChannel(img.Channel.alpha).toInt();

    // Fully transparent = not boundary
    if (a == 0) return false;

    // Luminance formula: 0.299R + 0.587G + 0.114B
    final brightness = (r * 299 + g * 587 + b * 114) ~/ 1000;
    return brightness < _brightnessThreshold;
  }

  /// Check if pixel can be filled based on current mode
  bool _canFill(int x, int y) {
    if (x < 0 || x >= _width || y < 0 || y >= _height) return false;

    final idx = y * _width + x;
    if (_visited![idx] == 1) return false;

    if (_mode == FillMode.brightness) {
      return !_isBoundary(x, y);
    }

    // Tolerance mode - check color match
    final pixel = image!.getPixelSafe(x, y);
    final r = pixel.getChannel(img.Channel.red).toInt();
    final g = pixel.getChannel(img.Channel.green).toInt();
    final b = pixel.getChannel(img.Channel.blue).toInt();
    final a = pixel.getChannel(img.Channel.alpha).toInt();

    // Skip dark pixels even in tolerance mode
    final brightness = ((r + g + b) / 3).round();
    if (brightness < _brightnessThreshold) return false;

    return (r >= _startColor.r - _tolerance &&
            r <= _startColor.r + _tolerance) &&
        (g >= _startColor.g - _tolerance && g <= _startColor.g + _tolerance) &&
        (b >= _startColor.b - _tolerance && b <= _startColor.b + _tolerance) &&
        (a >= _startColor.a - _tolerance && a <= _startColor.a + _tolerance);
  }

  /// Fill pixel and mark as visited
  void _fillPixel(int x, int y) {
    final idx = y * _width + x;
    _visited![idx] = 1;
    image!.setPixel(x, y, _fillColor);
  }

  /// Scanline flood fill with span tracking
  /// Algorithm: scan left to boundary, fill right, track spans above/below
  Future<void> floodFill(int x, int y) async {
    // Initialize visited array and stack
    _visited = Uint8List(_width * _height);

    // Check starting pixel
    if (!_canFill(x, y)) return;

    // In tolerance mode, get start color from clicked pixel
    if (_mode == FillMode.tolerance) {
      final pixel = image!.getPixelSafe(x, y);
      _startColor = img.ColorInt16.rgba(
        pixel.getChannel(img.Channel.red).toInt(),
        pixel.getChannel(img.Channel.green).toInt(),
        pixel.getChannel(img.Channel.blue).toInt(),
        pixel.getChannel(img.Channel.alpha).toInt(),
      );
    }

    _stack = [y * _width + x];

    while (_stack.isNotEmpty) {
      final pos = _stack.removeLast();
      int px = pos % _width;
      final py = pos ~/ _width;

      // Scan left to boundary
      while (px > 0 && _canFill(px - 1, py)) {
        px--;
      }

      bool spanAbove = false;
      bool spanBelow = false;

      // Fill right with span tracking
      while (px < _width && _canFill(px, py)) {
        _fillPixel(px, py);

        // Track span above - only push once per span
        if (!spanAbove && py > 0 && _canFill(px, py - 1)) {
          _stack.add((py - 1) * _width + px);
          spanAbove = true;
        } else if (spanAbove && py > 0 && !_canFill(px, py - 1)) {
          spanAbove = false;
        }

        // Track span below - only push once per span
        if (!spanBelow && py < _height - 1 && _canFill(px, py + 1)) {
          _stack.add((py + 1) * _width + px);
          spanBelow = true;
        } else if (spanBelow && py < _height - 1 && !_canFill(px, py + 1)) {
          spanBelow = false;
        }

        px++;
      }
    }
  }
}
