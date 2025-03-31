import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //============================STUDY MATERIAL===================================================
  // Upload study material to Firebase Storage
  Future<String?> uploadStudyMaterial(File file) async {
    try {
      String fileName = file.path.split('/').last;
      String userId = _auth.currentUser!.uid;
      Reference storageRef =
          _storage.ref().child('study_materials/$userId/$fileName');

      // Upload the file
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading file: $e");
      return null;
    }
  }

  // Upload file to Firebase Storage
  Future<String?> uploadFile(File file, String path) async {
    try {
      TaskSnapshot snapshot = await _storage.ref(path).putFile(file);
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading file: $e");
      return null;
    }
  }

  // Delete file from Firebase Storage
  Future<void> deleteFile(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (e) {
      print("Error deleting file: $e");
    }
  }

  // Download file from Firebase Storage
  Future<File?> downloadFile(String url, String fileName) async {
    try {
      // Create a reference to the file
      Reference ref = _storage.refFromURL(url);

      // Create a temporary directory
      final Directory tempDir = await Directory.systemTemp.createTemp();
      final File file = File('${tempDir.path}/$fileName');

      // Download the file
      await ref.writeToFile(file);

      return file;
    } catch (e) {
      print("Error downloading file: $e");
      return null;
    }
  }
}
