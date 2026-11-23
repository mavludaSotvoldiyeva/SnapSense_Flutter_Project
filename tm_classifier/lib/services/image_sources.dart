import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ImageSources {
  final ImagePicker _picker = ImagePicker();

  Future<Uint8List?> fromCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
    return file?.readAsBytes();
  }

  Future<Uint8List?> fromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    return file?.readAsBytes();
  }

  Future<Uint8List> fromUrl(String address) async {
    final uri = Uri.tryParse(address.trim());
    if (uri == null || !['https', 'http'].contains(uri.scheme) || uri.host.isEmpty) {
      throw const FormatException('Enter a valid http or https image URL.');
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('Download failed (HTTP ${response.statusCode}).');
    if (!(response.headers['content-type'] ?? '').toLowerCase().startsWith('image/')) {
      throw const FormatException('This URL does not return an image.');
    }
    return response.bodyBytes;
  }
}
