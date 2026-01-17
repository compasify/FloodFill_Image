import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:floodfill_image/src/scanline_floodfiller.dart';

void main() {
  test('Debug fill - check pixel values', () async {
    final image = img.Image(width: 5, height: 5);

    // Fill with white
    for (int y = 0; y < 5; y++) {
      for (int x = 0; x < 5; x++) {
        image.setPixel(x, y, img.ColorRgb8(255, 255, 255));
      }
    }

    // Check what pixel values look like
    final testPixel = image.getPixelSafe(2, 2);
    print('Test pixel R: ${testPixel.getChannel(img.Channel.red).toInt()}');
    print('Test pixel G: ${testPixel.getChannel(img.Channel.green).toInt()}');
    print('Test pixel B: ${testPixel.getChannel(img.Channel.blue).toInt()}');
    print('Test pixel A: ${testPixel.getChannel(img.Channel.alpha).toInt()}');

    final brightness = (testPixel.getChannel(img.Channel.red).toInt() * 299 +
            testPixel.getChannel(img.Channel.green).toInt() * 587 +
            testPixel.getChannel(img.Channel.blue).toInt() * 114) ~/
        1000;
    print('Calculated brightness: $brightness');
    print('Threshold: 80');
    print('Is boundary (should be false for white): ${brightness < 80}');

    final filler = ScanlineFloodFiller(image, Colors.red);
    filler.useBrightnessMode(80);

    print('Fill color before fill: ${filler.getFillColor()}');

    await filler.floodFill(2, 2);

    final filledPixel = image.getPixelSafe(2, 2);
    print('After fill R: ${filledPixel.getChannel(img.Channel.red).toInt()}');
    print('After fill G: ${filledPixel.getChannel(img.Channel.green).toInt()}');
    print('After fill B: ${filledPixel.getChannel(img.Channel.blue).toInt()}');
  });
}
