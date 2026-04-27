import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadImage(File file, String userId) async {
    try {
      final ext = p.extension(file.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final ref = _storage.ref().child('requests/images/$userId/$fileName');
      
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<String?> uploadAudio(File file, String userId) async {
    try {
      final ext = p.extension(file.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final ref = _storage.ref().child('requests/audio/$userId/$fileName');
      
      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'audio/m4a'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading audio: $e');
      return null;
    }
  }
}
