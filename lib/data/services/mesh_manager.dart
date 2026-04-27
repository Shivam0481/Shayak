import 'dart:async';
import 'dart:convert';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import '../models/request_model.dart';

/// Simulates a P2P mesh network using flutter_nearby_connections.
/// Devices discover each other, exchange rescue requests,
/// and forward data to other connected peers (multi-hop A→B→C).
class MeshManager {
  late NearbyService _nearbyService;
  List<Device> _connectedDevices = [];
  late StreamSubscription _stateSubscription;
  late StreamSubscription _dataSubscription;

  final _requestController = StreamController<RequestModel>.broadcast();

  /// Stream of incoming requests received from mesh peers.
  Stream<RequestModel> get requestStream => _requestController.stream;

  List<Device> get connectedDevices => _connectedDevices;

  Future<void> init() async {
    _nearbyService = NearbyService();

    await _nearbyService.init(
      serviceType: 'shayak-mesh',   // must be <= 15 chars
      strategy: Strategy.P2P_CLUSTER,
      callback: (bool isRunning) {
        if (isRunning) {
          _nearbyService.startAdvertisingPeer();
          _nearbyService.startBrowsingForPeers();
        }
      },
    );

    // Listen for device state changes (found / connecting / connected)
    _stateSubscription = _nearbyService.stateChangedSubscription(
      callback: (List<Device> devices) {
        _connectedDevices = devices;
        for (final device in devices) {
          if (device.state == SessionState.notConnected) {
            // Automatically invite discovered, not-yet-connected peers
            _nearbyService.invitePeer(
              deviceID: device.deviceId,
              deviceName: device.deviceName,
            );
          }
        }
      },
    );

    // Listen for incoming data payloads
    _dataSubscription = _nearbyService.dataReceivedSubscription(
      callback: (dynamic rawData) {
        try {
          final payload = json.decode(rawData['message'] as String)
              as Map<String, dynamic>;
          if (payload['type'] == 'FORWARD_REQUEST') {
            final requestJson =
                payload['payload'] as Map<String, dynamic>;
            final request = RequestModel.fromJson(requestJson);
            _requestController.add(request);

            // Multi-hop: forward to all other connected peers
            _forwardToPeers(
              request,
              excludeDeviceId: rawData['deviceId'] as String?,
            );
          }
        } catch (e) {
          // Ignore malformed payloads
        }
      },
    );
  }

  /// Broadcasts a rescue request to all directly connected peers.
  void broadcastRequest(RequestModel request) {
    _forwardToPeers(request);
  }

  void _forwardToPeers(
    RequestModel request, {
    String? excludeDeviceId,
  }) {
    final payload = json.encode({
      'type': 'FORWARD_REQUEST',
      'payload': request.toJson(),
    });

    for (final device in _connectedDevices) {
      if (device.state == SessionState.connected &&
          device.deviceId != excludeDeviceId) {
        _nearbyService.sendMessage(device.deviceId, payload);
      }
    }
  }

  Future<void> dispose() async {
    await _stateSubscription.cancel();
    await _dataSubscription.cancel();
    _requestController.close();
    await _nearbyService.stopBrowsingForPeers();
    await _nearbyService.stopAdvertisingPeer();
  }
}
