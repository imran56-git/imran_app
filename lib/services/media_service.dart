import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class MediaService {
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (_) {}
    return null;
  }

  Future<File?> captureImageFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (_) {}
    return null;
  }

  Future<File?> pickVideoFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (_) {}
    return null;
  }

  Future<File?> captureVideoFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.camera,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (_) {}
    return null;
  }

  Future<File?> pickDocument() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xlsx', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
    } catch (_) {}
    return null;
  }

  Future<File?> pickAudio() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
    } catch (_) {}
    return null;
  }

  // এটিকে অ-নাল File রিটার্ন টাইপ করে দেওয়া হলো যাতে অ্যাসাইনমেন্টে ভুল না হয়
  Future<File> compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        '${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}',
      );
      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 50,
      );
      if (result != null) {
        return File(result.path);
      }
    } catch (_) {}
    return file; // ফেইল করলে বা নাল হলে ওরিজিনাল ফাইল ব্যাক করবে
  }

  Future<String?> uploadMedia({
    required File file,
    required String chatId,
    required String mediaType,
  }) async {
    try {
      File fileToUpload = file;
      if (mediaType == 'image') {
        fileToUpload = await compressImage(file); // এখন আর টাইপ মিসম্যাচ এরর হবে না
      }
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(fileToUpload.path)}';
      final Reference ref = _storage.ref().child('chatMedia').child(chatId).child(mediaType).child(fileName);
      final UploadTask uploadTask = ref.putFile(fileToUpload);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (_) {}
    return null;
  }

  Future<void> deleteMedia(String fileUrl) async {
    try {
      final Reference ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (_) {}
  }
}
