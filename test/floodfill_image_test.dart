import 'package:flutter_test/flutter_test.dart';
import 'package:floodfill_image/floodfill_image.dart';
import 'package:image/image.dart' as img;
import 'dart:ui';

void main() {
  group('QueueLinearFloodFiller', () {
    group('Brightness Threshold', () {
      test('setBrightnessThreshold should clamp value between 0-255', () {
        // Create a simple 10x10 white image
        final image = img.Image(width: 10, height: 10);
        for (int y = 0; y < 10; y++) {
          for (int x = 0; x < 10; x++) {
            image.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
          }
        }

        final filler = QueueLinearFloodFiller(image, const Color(0xFFFF0000));

        // Test default value
        expect(filler.getBrightnessThreshold(), equals(128));

        // Test setting valid value
        filler.setBrightnessThreshold(50);
        expect(filler.getBrightnessThreshold(), equals(50));

        // Test clamping lower bound
        filler.setBrightnessThreshold(-10);
        expect(filler.getBrightnessThreshold(), equals(0));

        // Test clamping upper bound
        filler.setBrightnessThreshold(300);
        expect(filler.getBrightnessThreshold(), equals(255));
      });

      test('_checkPixel should reject dark pixels', () async {
        // Create a 10x10 image with:
        // - Left half (x=0-4): Black pixels (brightness 0)
        // - Right half (x=5-9): White pixels (brightness 255)
        final image = img.Image(width: 10, height: 10);
        for (int y = 0; y < 10; y++) {
          for (int x = 0; x < 10; x++) {
            if (x < 5) {
              // Black pixels
              image.setPixel(x, y, img.ColorRgba8(0, 0, 0, 255));
            } else {
              // White pixels
              image.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
            }
          }
        }

        final filler = QueueLinearFloodFiller(image, const Color(0xFFFF0000));
        filler.setBrightnessThreshold(128);
        filler.setTargetColor(const Color(0xFFFFFFFF)); // Target white pixels

        // Fill from white area (x=7, y=5)
        await filler.floodFill(7, 5);

        // Check white area was filled (right half)
        final filledPixel = filler.image!.getPixel(7, 5);
        expect(filledPixel.r.toInt(), equals(255)); // Red (fill color)

        // Check black area was NOT filled (left half should remain black)
        final blackPixel = filler.image!.getPixel(2, 5);
        expect(blackPixel.r.toInt(), equals(0)); // Still black
      });

      test('flood fill should stop at dark boundaries', () async {
        // Create a 10x10 image with:
        // - A white area
        // - A black vertical line at x=5
        // - Another white area after the line
        final image = img.Image(width: 10, height: 10);
        for (int y = 0; y < 10; y++) {
          for (int x = 0; x < 10; x++) {
            if (x == 5) {
              // Black line in the middle
              image.setPixel(x, y, img.ColorRgba8(0, 0, 0, 255));
            } else {
              // White pixels
              image.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
            }
          }
        }

        final filler = QueueLinearFloodFiller(image, const Color(0xFF00FF00));
        filler.setBrightnessThreshold(128);
        filler.setTargetColor(const Color(0xFFFFFFFF));

        // Fill from left side of the black line (x=2, y=5)
        await filler.floodFill(2, 5);

        // Left side should be filled (green)
        final leftPixel = filler.image!.getPixel(2, 5);
        expect(leftPixel.g.toInt(), equals(255)); // Green (fill color)

        // Black line should NOT be filled
        final linePixel = filler.image!.getPixel(5, 5);
        expect(linePixel.r.toInt(), equals(0)); // Still black

        // Right side should NOT be filled (still white)
        // because the black line acts as a boundary
        final rightPixel = filler.image!.getPixel(7, 5);
        expect(rightPixel.r.toInt(), equals(255)); // Still white
        expect(rightPixel.g.toInt(), equals(255));
        expect(rightPixel.b.toInt(), equals(255));
      });
    });
  });
}
