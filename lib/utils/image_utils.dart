import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageHelper {
  static Future<File?> compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final String targetPath = "${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path, 
      targetPath,
      quality: 70, 
      format: CompressFormat.jpeg,
    );

    return result != null ? File(result.path) : null;
  }
}
