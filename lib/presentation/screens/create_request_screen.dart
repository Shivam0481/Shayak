import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/rescue_request.dart';
import '../../domain/logic/priority_calculator.dart';
import '../../data/models/request_model.dart';
import '../../data/services/sync_service.dart';
import '../../data/services/storage_service.dart';
import '../providers/app_providers.dart';

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({
    super.key,
    this.isSOS = false,
    this.initialType,
  });

  final bool isSOS;
  final RequestType? initialType;

  @override
  ConsumerState<CreateRequestScreen> createState() =>
      _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  late RequestType _selectedType;
  double _urgency = 5;
  XFile? _photo;
  
  final _audioRecorder = AudioRecorder();
  File? _audioFile;
  bool _isRecording = false;
  
  bool _isSubmitting = false;
  LatLng? _pickedLocation;
  GoogleMapController? _mapController;

  static const _types = [
    (RequestType.food, Icons.restaurant, 'Food'),
    (RequestType.blood, Icons.bloodtype, 'Blood'),
    (RequestType.medicine, Icons.medical_services, 'Medicine'),
    (RequestType.rescue, Icons.waves, 'Rescue'),
    (RequestType.mentalHealth, Icons.psychology, 'Mental Health'),
    (RequestType.transport, Icons.directions_car, 'Transport'),
    (RequestType.labour, Icons.construction, 'Labour'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? RequestType.food;
    if (widget.isSOS) {
      _urgency = 10;
      _descCtrl.text = '🆘 EMERGENCY SOS – Immediate rescue required!';
    }
    
    // Initial location from provider
    final loc = ref.read(userLocationProvider);
    if (loc != null) {
      _pickedLocation = LatLng(loc.lat, loc.lng);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
    if (file != null) setState(() => _photo = file);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        if (path != null) _audioFile = File(path);
      });
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = p.join(dir.path, 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final userAsync = await ref.read(authRepoProvider).getCurrentUserDoc();
      if (userAsync == null) throw Exception('Not logged in');

      final lat = _pickedLocation?.latitude ?? 0.0;
      final lng = _pickedLocation?.longitude ?? 0.0;

      final storage = StorageService();
      String? photoUrl;
      String? voiceUrl;

      if (_photo != null) {
        photoUrl = await storage.uploadImage(File(_photo!.path), userAsync.uid);
      }
      
      if (_audioFile != null) {
        voiceUrl = await storage.uploadAudio(_audioFile!, userAsync.uid);
      }

      final score = PriorityCalculator.calculateScore(
        urgency: _urgency,
        distanceInKm: 0,
        resourceScarcity: _urgency / 10,
      );

      final request = RescueRequest(
        id: const Uuid().v4(),
        creatorId: userAsync.uid,
        type: _selectedType,
        description: _descCtrl.text.trim(),
        urgency: _urgency,
        location: LatLng(lat, lng),
        photoUrl: photoUrl,
        voiceUrl: voiceUrl,
        status: RequestStatus.pending,
        priorityScore: score,
        timestamp: DateTime.now(),
      );

      // Save to Firestore
      await ref.read(requestRepoProvider).createRequest(request);

      final model = RequestModel.fromEntity(request);
      final syncService = SyncService();
      await syncService.init();
      await syncService.saveRequestLocally(model);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted!'),
            backgroundColor: AppColors.priorityGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.priorityRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isSOS ? '🆘 SOS Alert' : 'Create Request'),
        backgroundColor:
            widget.isSOS ? AppColors.priorityRed : AppColors.primaryBlue,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Request Type
                const Text('Category',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _types.map((t) {
                      final selected = _selectedType == t.$1;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedType = t.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryBlue
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primaryBlue
                                  : Colors.grey.shade200,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(t.$2,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.primaryBlue,
                                  size: 28),
                              const SizedBox(height: 4),
                              Text(t.$3,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: selected
                                          ? Colors.white
                                          : AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Description
                const Text('Description',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Describe your situation...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primaryBlue, width: 2),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Please describe the situation'
                      : null,
                ),
                const SizedBox(height: 24),

                // Urgency Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Urgency Level',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _urgencyColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${_urgency.toInt()}/10',
                          style: TextStyle(
                              color: _urgencyColor,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Slider(
                  value: _urgency,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: _urgencyColor,
                  onChanged: (v) => setState(() => _urgency = v),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Attach Photo',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                                height: 140,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: AppColors.lightBlue, width: 2,
                                      style: BorderStyle.solid),
                                ),
                                child: _photo != null
                                    ? Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: kIsWeb 
                                              ? Image.network(_photo!.path,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  fit: BoxFit.cover)
                                              : Image.file(File(_photo!.path),
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  fit: BoxFit.cover),
                                          ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _photo = null),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppColors.priorityRed,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Icon(Icons.close,
                                                  color: Colors.white, size: 20),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt,
                                            color: AppColors.primaryBlue, size: 28),
                                        SizedBox(height: 4),
                                        Text('Tap to add photo',
                                            style: TextStyle(color: AppColors.primaryBlue, fontSize: 12)),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Voice Note',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _toggleRecording,
                            child: Container(
                              height: _audioFile != null ? 140 : 80,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: _isRecording ? AppColors.priorityRed.withOpacity(0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: _isRecording ? AppColors.priorityRed : AppColors.lightBlue, width: 2,
                                    style: BorderStyle.solid),
                              ),
                              child: _audioFile != null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.audio_file, color: AppColors.primaryBlue, size: 40),
                                        const SizedBox(height: 8),
                                        const Text('Audio attached', style: TextStyle(color: AppColors.primaryBlue, fontSize: 12)),
                                        TextButton(
                                          onPressed: () => setState(() => _audioFile = null),
                                          child: const Text('Remove', style: TextStyle(color: AppColors.priorityRed)),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(_isRecording ? Icons.stop_circle : Icons.mic,
                                            color: _isRecording ? AppColors.priorityRed : AppColors.primaryBlue, size: 28),
                                        const SizedBox(height: 4),
                                        Text(_isRecording ? 'Tap to stop' : 'Tap to record',
                                            style: TextStyle(color: _isRecording ? AppColors.priorityRed : AppColors.primaryBlue, fontSize: 12)),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Request Location',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _pickedLocation == null 
                      ? const Center(child: CircularProgressIndicator())
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _pickedLocation!,
                            zoom: 15,
                          ),
                          onMapCreated: (ctrl) => _mapController = ctrl,
                          markers: {
                            Marker(
                              markerId: const MarkerId('picked'),
                              position: _pickedLocation!,
                              draggable: true,
                              onDragEnd: (pos) => setState(() => _pickedLocation = pos),
                            )
                          },
                          onTap: (pos) => setState(() => _pickedLocation = pos),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                        ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isSOS
                        ? AppColors.priorityRed
                        : AppColors.primaryBlue,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          widget.isSOS ? 'SEND SOS NOW' : 'Submit Request',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color get _urgencyColor {
    if (_urgency >= 8) return AppColors.priorityRed;
    if (_urgency >= 5) return AppColors.priorityYellow;
    return AppColors.priorityGreen;
  }
}
