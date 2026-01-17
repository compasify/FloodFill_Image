import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:floodfill_image/src/scanline_floodfiller.dart';

void main() {
  group('ScanlineFloodFiller', () {
    test('Basic fill - white area gets filled', () async {
      // Create 10x10 white image
      final image = img.Image(width: 10, height: 10);
      for (int y = 0; y < 10; y++) {
        for (int x = 0; x < 10; x++) {
          image.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
        }
      }

      final filler = ScanlineFloodFiller(image, Colors.red);
      filler.useBrightnessMode(80);

      await filler.floodFill(5, 5);

      // Verify pixels got filled (changed from white)
      final centerPixel = image.getPixelSafe(5, 5);
      final r = centerPixel.getChannel(img.Channel.red).toInt();
      final g = centerPixel.getChannel(img.Channel.green).toInt();

      expect(r, greaterThan(200)); // Should be red now
      expect(g, lessThan(100)); // Not green
    });

    test('Brightness boundary - dark line stops fill', () async {
      final image = img.Image(width: 10, height: 10);

      // Top half: light gray (200)
      for (int y = 0; y < 5; y++) {
        for (int x = 0; x < 10; x++) {
          image.setPixel(x, y, img.ColorRgba8(200, 200, 200, 255));
        }
      }

      // Middle row: dark line (30)
      for (int x = 0; x < 10; x++) {
        image.setPixel(x, 5, img.ColorRgba8(30, 30, 30, 255));
      }

      // Bottom half: light gray
      for (int y = 6; y < 10; y++) {
        for (int x = 0; x < 10; x++) {
          image.setPixel(x, y, img.ColorRgba8(200, 200, 200, 255));
        }
      }

      final filler = ScanlineFloodFiller(image, Colors.blue);
      filler.useBrightnessMode(80); // Dark line (30) should block

      // Fill top half
      await filler.floodFill(5, 2);

      // Top should be filled (blue)
      final topPixel = image.getPixelSafe(5, 2);
      final topB = topPixel.getChannel(img.Channel.blue).toInt();
      expect(topB, greaterThan(150));

      // Bottom should NOT be filled (still gray, not blue)
      final bottomPixel = image.getPixelSafe(5, 8);
      final bottomB = bottomPixel.getChannel(img.Channel.blue).toInt();
      final bottomR = bottomPixel.getChannel(img.Channel.red).toInt();
      expect(bottomB, lessThan(100)); // Not filled with blue
      expect(bottomR, greaterThan(150)); // Still gray

      // Dark line should be unchanged
      final darkPixel = image.getPixelSafe(5, 5);
      final darkR = darkPixel.getChannel(img.Channel.red).toInt();
      expect(darkR, lessThan(100)); // Still dark
    });

    test('API compatibility - setters work', () async {
      final image = img.Image(width: 5, height: 5);
      for (int y = 0; y < 5; y++) {
        for (int x = 0; x < 5; x++) {
          image.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
        }
      }

      final filler = ScanlineFloodFiller(image, Colors.red);

      // Test all setters don't throw
      expect(() => filler.setFillColor(Colors.blue), returnsNormally);
      expect(() => filler.setTolerance(20), returnsNormally);
      expect(() => filler.setBrightnessThreshold(100), returnsNormally);
      expect(() => filler.setTargetColor(Colors.white), returnsNormally);
      expect(() => filler.resize(const Size(5, 5)), returnsNormally);

      expect(filler.getBrightnessThreshold(), 100);

      // Fill works
      await filler.floodFill(2, 2);
      final pixel = image.getPixelSafe(2, 2);
      final b = pixel.getChannel(img.Channel.blue).toInt();
      expect(b, greaterThan(150)); // Filled with blue
    });

    test('Edge case - very small image', () async {
      final image = img.Image(width: 3, height: 3);
      for (int y = 0; y < 3; y++) {
        for (int x = 0; x < 3; x++) {
          image.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
        }
      }

      final filler = ScanlineFloodFiller(image, Colors.green);
      filler.useBrightnessMode(80);

      await filler.floodFill(1, 1);

      final pixel = image.getPixelSafe(1, 1);
      final g = pixel.getChannel(img.Channel.green).toInt();
      expect(g, greaterThan(200));
    });

    test('Boundary check - out of bounds coordinates', () async {
      final image = img.Image(width: 5, height: 5);
      for (int y = 0; y < 5; y++) {
        for (int x = 0; x < 5; x++) {
          image.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
        }
      }

      final filler = ScanlineFloodFiller(image, Colors.red);
      filler.useBrightnessMode(80);

      // Should not crash on out-of-bounds start
      await filler.floodFill(-1, -1);
      await filler.floodFill(100, 100);

      // Image should be unchanged (white)
      final pixel = image.getPixelSafe(2, 2);
      final r = pixel.getChannel(img.Channel.red).toInt();
      expect(r, closeTo(255, 10)); // Still white
    });
  });
}
