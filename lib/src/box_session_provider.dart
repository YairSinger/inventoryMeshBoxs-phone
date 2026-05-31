import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../protocol.dart';
import 'ble_client.dart';

class PendingTag {
  final String uid;
  int retryCount;

  PendingTag({required this.uid, this.retryCount = 0});
}

class BoxSessionProvider extends ChangeNotifier {
  final IBleClient bleClient;
  
  imb_op_mode _currentMode = imb_op_mode.mode_field_check;
  bool _isRegistrationIncomplete = false;
  
  final Queue<PendingTag> _pendingTags = Queue<PendingTag>();
  final List<ReportEntry> _registeredItems = [];

  // Expose state
  imb_op_mode get currentMode => _currentMode;
  bool get isRegistrationIncomplete => _isRegistrationIncomplete;
  Queue<PendingTag> get pendingTags => _pendingTags;
  List<ReportEntry> get registeredItems => _registeredItems;
  bool get hasPendingTags => _pendingTags.isNotEmpty;

  StreamSubscription<List<int>>? _eventSub;
  
  // Acompleter for the currently active CMD_NAME operation
  Completer<imb_ack_status>? _nameCompleter;

  BoxSessionProvider({required this.bleClient}) {
    // Listen to events from the BleClient
    // Note: In a real app, you might want to expose a stream from BleClient
    // instead of hooking into the generic receive method, but we'll assume
    // the UI will pass the raw byte arrays here or BleClient exposes an event stream.
    _eventSub = bleClient.eventStream.listen(_handleBleEvent);
  }

  void _handleBleEvent(List<int> data) {
    if (data.isEmpty) return;
    
    final msgType = data[0];
    
    if (msgType == imb_msg_typeValues[imb_msg_type.msg_event_mode]) {
       final modeEvent = EventMode.fromBytes(Uint8List.fromList(data));
       _currentMode = imb_op_mode.values.firstWhere(
          (m) => imb_op_modeValues[m] == modeEvent.mode,
          orElse: () => imb_op_mode.mode_field_check,
       );
       notifyListeners();
    } 
    else if (msgType == imb_msg_typeValues[imb_msg_type.msg_event_tag]) {
      final tagEvent = Eventag.fromBytes(Uint8List.fromList(data));
      // Only process un-named tags as pending registration
      if (tagEvent.name.isEmpty) {
         if (!_pendingTags.any((t) => t.uid == tagEvent.uid)) {
            _pendingTags.add(PendingTag(uid: tagEvent.uid));
            notifyListeners();
         }
      } else {
        // Registered item scan: update inventory list
        final entry = ReportEntry(
          box_id: 0, // Current box
          status: 0, // PRESENT
          uid: tagEvent.uid,
          name: tagEvent.name,
        );
        
        final existingIdx = _registeredItems.indexWhere((e) => e.uid == entry.uid);
        if (tagEvent.direction == 0) { // INSERT
          if (existingIdx == -1) {
            _registeredItems.add(entry);
          }
        } else if (tagEvent.direction == 1) { // EXTRACT
          if (existingIdx != -1) {
            _registeredItems.removeAt(existingIdx);
          }
        }
        notifyListeners();
      }
    }
    else if (msgType == imb_msg_typeValues[imb_msg_type.msg_event_ack]) {
       final ack = EventAck.fromBytes(Uint8List.fromList(data));
       
       if (ack.acked_msg_type == imb_msg_typeValues[imb_msg_type.msg_cmd_name]) {
          final status = imb_ack_status.values.firstWhere(
            (st) => imb_ack_statusValues[st] == ack.status,
            orElse: () => imb_ack_status.ack_not_authed,
          );
          _nameCompleter?.complete(status);
       }
       else if (ack.acked_msg_type == imb_msg_typeValues[imb_msg_type.msg_cmd_mode]) {
          if (ack.status == imb_ack_statusValues[imb_ack_status.ack_registration_incomplete]) {
             _isRegistrationIncomplete = true;
             notifyListeners();
          }
       }
    }
  }

  // Set flags from advertisement (e.g., sticky registration)
  void setInitialFlags(int opMode, int flags) {
      if (opMode == imb_ack_statusValues[imb_ack_status.ack_registration_incomplete]) {
         _isRegistrationIncomplete = true;
      }
      notifyListeners();
  }

  Future<bool> startRegistration() async {
     final cmd = CmdMode(
       msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_mode]!,
       msg_id: 10, // arbitrary id
       mode: imb_op_modeValues[imb_op_mode.mode_registration]!
     );
     
     await bleClient.sendCommand(cmd.toBytes());
     // Mode will update via EVENT_MODE
     return true;
  }

  Future<bool> endRegistration() async {
     if (_pendingTags.isNotEmpty) {
        return false; // Pre-emptive block
     }
     final cmd = CmdMode(
       msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_mode]!,
       msg_id: 11,
       mode: imb_op_modeValues[imb_op_mode.mode_field_check]!
     );
     await bleClient.sendCommand(cmd.toBytes());
     return true;
  }

  Future<imb_ack_status> namePendingTag(String name) async {
      if (_pendingTags.isEmpty) return imb_ack_status.ack_unknown_uid;
      
      final currentTag = _pendingTags.first;
      imb_ack_status status = imb_ack_status.ack_not_authed;

      // Automatic Retry Loop (Option A)
      for (int i = 0; i < 3; i++) {
        _nameCompleter = Completer<imb_ack_status>();
        
        final cmd = CmdName(
          msg_type: imb_msg_typeValues[imb_msg_type.msg_cmd_name]!,
          msg_id: 20 + i,
          uid: currentTag.uid,
          name: name,
        );

        await bleClient.sendCommand(cmd.toBytes());
        
        try {
          status = await _nameCompleter!.future.timeout(const Duration(seconds: 3));
          if (status == imb_ack_status.ack_ok) {
             _pendingTags.removeFirst();
             notifyListeners();
             return status;
          }
          if (status != imb_ack_status.ack_ndef_write_failed) {
             break; // Fatal error
          }
        } on TimeoutException {
          status = imb_ack_status.ack_not_authed; 
        }
        
        if (i < 2) await Future.delayed(const Duration(milliseconds: 500));
      }
      
      return status;
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}
