// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: components/imb_protocol/include/imb_protocol.h
import 'dart:typed_data';

const int IMB_UID_LEN = 15;
const int IMB_NAME_LEN = 32;
const int IMB_REGISTRY_MAX_ITEMS = 64;
const int IMB_MESH_MAX_BOXES = 8;
const int IMB_REPORT_MAX_ENTRIES = 512;
const int IMB_PROTO_BUF_MAX = 256;
const String IMB_SERVICE_UUID = "e5d50000-01d0-47e0-afc5-01e466d9298e";
const String IMB_CHAR_EVENT_NOTIFY = "e5d50001-01d0-47e0-afc5-01e466d9298e";
const String IMB_CHAR_REPORT_NOTIFY = "e5d50002-01d0-47e0-afc5-01e466d9298e";
const String IMB_CHAR_COMMAND_WRITE = "e5d50003-01d0-47e0-afc5-01e466d9298e";

enum imb_op_mode {
  mode_setup, // 0
  mode_field_check, // 1
  mode_registration, // 2
  mode_registration_incomplete, // 3
}

const Map<imb_op_mode, int> imb_op_modeValues = {
  imb_op_mode.mode_setup: 0,
  imb_op_mode.mode_field_check: 1,
  imb_op_mode.mode_registration: 2,
  imb_op_mode.mode_registration_incomplete: 3,
};

enum imb_msg_type {
  msg_event_tag, // 1
  msg_event_mode, // 2
  msg_report_chunk, // 3
  msg_event_ack, // 4
  msg_event_dropped, // 5
  msg_event_log_chunk, // 6
  msg_cmd_mode, // 16
  msg_cmd_name, // 17
  msg_cmd_accept, // 18
  msg_cmd_hello, // 19
  msg_cmd_set_pin, // 20
  msg_cmd_report_ack, // 21
  msg_cmd_report_nack, // 22
  msg_cmd_unbond, // 23
  msg_cmd_get_log, // 24
  msg_cmd_mesh_status, // 25
}

const Map<imb_msg_type, int> imb_msg_typeValues = {
  imb_msg_type.msg_event_tag: 1,
  imb_msg_type.msg_event_mode: 2,
  imb_msg_type.msg_report_chunk: 3,
  imb_msg_type.msg_event_ack: 4,
  imb_msg_type.msg_event_dropped: 5,
  imb_msg_type.msg_event_log_chunk: 6,
  imb_msg_type.msg_cmd_mode: 16,
  imb_msg_type.msg_cmd_name: 17,
  imb_msg_type.msg_cmd_accept: 18,
  imb_msg_type.msg_cmd_hello: 19,
  imb_msg_type.msg_cmd_set_pin: 20,
  imb_msg_type.msg_cmd_report_ack: 21,
  imb_msg_type.msg_cmd_report_nack: 22,
  imb_msg_type.msg_cmd_unbond: 23,
  imb_msg_type.msg_cmd_get_log: 24,
  imb_msg_type.msg_cmd_mesh_status: 25,
};

enum imb_ack_status {
  ack_ok, // 0
  ack_pin_mismatch, // 1
  ack_registry_full, // 2
  ack_ndef_write_failed, // 3
  ack_invalid_mode, // 4
  ack_unknown_uid, // 5
  ack_not_authed, // 6
  ack_registration_incomplete, // 7
  ack_log_overflow, // 8
}

const Map<imb_ack_status, int> imb_ack_statusValues = {
  imb_ack_status.ack_ok: 0,
  imb_ack_status.ack_pin_mismatch: 1,
  imb_ack_status.ack_registry_full: 2,
  imb_ack_status.ack_ndef_write_failed: 3,
  imb_ack_status.ack_invalid_mode: 4,
  imb_ack_status.ack_unknown_uid: 5,
  imb_ack_status.ack_not_authed: 6,
  imb_ack_status.ack_registration_incomplete: 7,
  imb_ack_status.ack_log_overflow: 8,
};

class CmdHeader {
  final int msg_type;
  final int msg_id;

  CmdHeader({
    required this.msg_type,
    required this.msg_id,
  });

  factory CmdHeader.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['msg_type'] = data.getUint8(offset);
    offset += 1;
    inits['msg_id'] = data.getUint8(offset);
    offset += 1;
    return CmdHeader(
      msg_type: inits['msg_type'],
      msg_id: inits['msg_id'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(1 + 1);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint8(offset, msg_type);
    offset += 1;
    data.setUint8(offset, msg_id);
    offset += 1;
    return bytes;
  }
}

class CmdHello {
  final int msg_type;
  final int msg_id;
  final int pin_hash;

  CmdHello({
    required this.msg_type,
    required this.msg_id,
    required this.pin_hash,
  });

  factory CmdHello.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['msg_type'] = data.getUint8(offset);
    offset += 1;
    inits['msg_id'] = data.getUint8(offset);
    offset += 1;
    inits['pin_hash'] = data.getUint32(offset, Endian.little);
    offset += 4;
    return CmdHello(
      msg_type: inits['msg_type'],
      msg_id: inits['msg_id'],
      pin_hash: inits['pin_hash'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(1 + 1 + 4);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint8(offset, msg_type);
    offset += 1;
    data.setUint8(offset, msg_id);
    offset += 1;
    data.setUint32(offset, pin_hash, Endian.little);
    offset += 4;
    return bytes;
  }
}

class EventAck {
  final int msg_type;
  final int acked_msg_id;
  final int acked_msg_type;
  final int status;

  EventAck({
    required this.msg_type,
    required this.acked_msg_id,
    required this.acked_msg_type,
    required this.status,
  });

  factory EventAck.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['msg_type'] = data.getUint8(offset);
    offset += 1;
    inits['acked_msg_id'] = data.getUint8(offset);
    offset += 1;
    inits['acked_msg_type'] = data.getUint8(offset);
    offset += 1;
    inits['status'] = data.getUint8(offset);
    offset += 1;
    return EventAck(
      msg_type: inits['msg_type'],
      acked_msg_id: inits['acked_msg_id'],
      acked_msg_type: inits['acked_msg_type'],
      status: inits['status'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(1 + 1 + 1 + 1);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint8(offset, msg_type);
    offset += 1;
    data.setUint8(offset, acked_msg_id);
    offset += 1;
    data.setUint8(offset, acked_msg_type);
    offset += 1;
    data.setUint8(offset, status);
    offset += 1;
    return bytes;
  }
}

class Eventag {
  final int msg_type;
  final int direction;
  final String uid;
  final String name;

  Eventag({
    required this.msg_type,
    required this.direction,
    required this.uid,
    required this.name,
  });

  factory Eventag.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['msg_type'] = data.getUint8(offset);
    offset += 1;
    inits['direction'] = data.getUint8(offset);
    offset += 1;
    inits['uid'] = String.fromCharCodes(bytes.sublist(offset, offset + IMB_UID_LEN)).split('\x00')[0];
    offset += IMB_UID_LEN;
    inits['name'] = String.fromCharCodes(bytes.sublist(offset, offset + IMB_NAME_LEN)).split('\x00')[0];
    offset += IMB_NAME_LEN;
    return Eventag(
      msg_type: inits['msg_type'],
      direction: inits['direction'],
      uid: inits['uid'],
      name: inits['name'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(1 + 1 + IMB_UID_LEN + IMB_NAME_LEN);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint8(offset, msg_type);
    offset += 1;
    data.setUint8(offset, direction);
    offset += 1;
    var uidBytes = Uint8List.fromList(uid.codeUnits);
    for (var i = 0; i < uidBytes.length && i < IMB_UID_LEN; i++) {
      bytes[offset + i] = uidBytes[i];
    }
    offset += IMB_UID_LEN;
    var nameBytes = Uint8List.fromList(name.codeUnits);
    for (var i = 0; i < nameBytes.length && i < IMB_NAME_LEN; i++) {
      bytes[offset + i] = nameBytes[i];
    }
    offset += IMB_NAME_LEN;
    return bytes;
  }
}

class EventMode {
  final int msg_type;
  final int mode;

  EventMode({
    required this.msg_type,
    required this.mode,
  });

  factory EventMode.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['msg_type'] = data.getUint8(offset);
    offset += 1;
    inits['mode'] = data.getUint8(offset);
    offset += 1;
    return EventMode(
      msg_type: inits['msg_type'],
      mode: inits['mode'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(1 + 1);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint8(offset, msg_type);
    offset += 1;
    data.setUint8(offset, mode);
    offset += 1;
    return bytes;
  }
}

class ReportChunk {
  final int msg_type;
  final int report_id;
  final int chunk_index;
  final int chunk_total;
  final int entries_in_chunk;

  ReportChunk({
    required this.msg_type,
    required this.report_id,
    required this.chunk_index,
    required this.chunk_total,
    required this.entries_in_chunk,
  });

  factory ReportChunk.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['msg_type'] = data.getUint8(offset);
    offset += 1;
    inits['report_id'] = data.getUint16(offset, Endian.little);
    offset += 2;
    inits['chunk_index'] = data.getUint16(offset, Endian.little);
    offset += 2;
    inits['chunk_total'] = data.getUint16(offset, Endian.little);
    offset += 2;
    inits['entries_in_chunk'] = data.getUint16(offset, Endian.little);
    offset += 2;
    return ReportChunk(
      msg_type: inits['msg_type'],
      report_id: inits['report_id'],
      chunk_index: inits['chunk_index'],
      chunk_total: inits['chunk_total'],
      entries_in_chunk: inits['entries_in_chunk'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(1 + 2 + 2 + 2 + 2);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint8(offset, msg_type);
    offset += 1;
    data.setUint16(offset, report_id, Endian.little);
    offset += 2;
    data.setUint16(offset, chunk_index, Endian.little);
    offset += 2;
    data.setUint16(offset, chunk_total, Endian.little);
    offset += 2;
    data.setUint16(offset, entries_in_chunk, Endian.little);
    offset += 2;
    return bytes;
  }
}

class ReportEntry {
  final int box_id;
  final int status;
  final String uid;
  final String name;

  ReportEntry({
    required this.box_id,
    required this.status,
    required this.uid,
    required this.name,
  });

  factory ReportEntry.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['box_id'] = data.getUint16(offset, Endian.little);
    offset += 2;
    inits['status'] = data.getUint8(offset);
    offset += 1;
    inits['uid'] = String.fromCharCodes(bytes.sublist(offset, offset + IMB_UID_LEN)).split('\x00')[0];
    offset += IMB_UID_LEN;
    inits['name'] = String.fromCharCodes(bytes.sublist(offset, offset + IMB_NAME_LEN)).split('\x00')[0];
    offset += IMB_NAME_LEN;
    return ReportEntry(
      box_id: inits['box_id'],
      status: inits['status'],
      uid: inits['uid'],
      name: inits['name'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(2 + 1 + IMB_UID_LEN + IMB_NAME_LEN);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint16(offset, box_id, Endian.little);
    offset += 2;
    data.setUint8(offset, status);
    offset += 1;
    var uidBytes = Uint8List.fromList(uid.codeUnits);
    for (var i = 0; i < uidBytes.length && i < IMB_UID_LEN; i++) {
      bytes[offset + i] = uidBytes[i];
    }
    offset += IMB_UID_LEN;
    var nameBytes = Uint8List.fromList(name.codeUnits);
    for (var i = 0; i < nameBytes.length && i < IMB_NAME_LEN; i++) {
      bytes[offset + i] = nameBytes[i];
    }
    offset += IMB_NAME_LEN;
    return bytes;
  }
}

class LogEntry {
  final int seq_id;
  final int box_id;
  final int event_type;
  final String uid;

  LogEntry({
    required this.seq_id,
    required this.box_id,
    required this.event_type,
    required this.uid,
  });

  factory LogEntry.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['seq_id'] = data.getUint16(offset, Endian.little);
    offset += 2;
    inits['box_id'] = data.getUint16(offset, Endian.little);
    offset += 2;
    inits['event_type'] = data.getUint8(offset);
    offset += 1;
    inits['uid'] = String.fromCharCodes(bytes.sublist(offset, offset + IMB_UID_LEN)).split('\x00')[0];
    offset += IMB_UID_LEN;
    return LogEntry(
      seq_id: inits['seq_id'],
      box_id: inits['box_id'],
      event_type: inits['event_type'],
      uid: inits['uid'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(2 + 2 + 1 + IMB_UID_LEN);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint16(offset, seq_id, Endian.little);
    offset += 2;
    data.setUint16(offset, box_id, Endian.little);
    offset += 2;
    data.setUint8(offset, event_type);
    offset += 1;
    var uidBytes = Uint8List.fromList(uid.codeUnits);
    for (var i = 0; i < uidBytes.length && i < IMB_UID_LEN; i++) {
      bytes[offset + i] = uidBytes[i];
    }
    offset += IMB_UID_LEN;
    return bytes;
  }
}

class CmdGetLog {
  final int msg_type;
  final int msg_id;
  final int last_seen_id;

  CmdGetLog({
    required this.msg_type,
    required this.msg_id,
    required this.last_seen_id,
  });

  factory CmdGetLog.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['msg_type'] = data.getUint8(offset);
    offset += 1;
    inits['msg_id'] = data.getUint8(offset);
    offset += 1;
    inits['last_seen_id'] = data.getUint16(offset, Endian.little);
    offset += 2;
    return CmdGetLog(
      msg_type: inits['msg_type'],
      msg_id: inits['msg_id'],
      last_seen_id: inits['last_seen_id'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(1 + 1 + 2);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint8(offset, msg_type);
    offset += 1;
    data.setUint8(offset, msg_id);
    offset += 1;
    data.setUint16(offset, last_seen_id, Endian.little);
    offset += 2;
    return bytes;
  }
}

class EventLogChunk {
  final int msg_type;
  final int chunk_index;
  final int chunk_total;
  final int entries_in_chunk;

  EventLogChunk({
    required this.msg_type,
    required this.chunk_index,
    required this.chunk_total,
    required this.entries_in_chunk,
  });

  factory EventLogChunk.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['msg_type'] = data.getUint8(offset);
    offset += 1;
    inits['chunk_index'] = data.getUint16(offset, Endian.little);
    offset += 2;
    inits['chunk_total'] = data.getUint16(offset, Endian.little);
    offset += 2;
    inits['entries_in_chunk'] = data.getUint8(offset);
    offset += 1;
    return EventLogChunk(
      msg_type: inits['msg_type'],
      chunk_index: inits['chunk_index'],
      chunk_total: inits['chunk_total'],
      entries_in_chunk: inits['entries_in_chunk'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(1 + 2 + 2 + 1);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint8(offset, msg_type);
    offset += 1;
    data.setUint16(offset, chunk_index, Endian.little);
    offset += 2;
    data.setUint16(offset, chunk_total, Endian.little);
    offset += 2;
    data.setUint8(offset, entries_in_chunk);
    offset += 1;
    return bytes;
  }
}

class CmdMode {
  final int msg_type;
  final int msg_id;
  final int mode;

  CmdMode({
    required this.msg_type,
    required this.msg_id,
    required this.mode,
  });

  factory CmdMode.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['msg_type'] = data.getUint8(offset);
    offset += 1;
    inits['msg_id'] = data.getUint8(offset);
    offset += 1;
    inits['mode'] = data.getUint8(offset);
    offset += 1;
    return CmdMode(
      msg_type: inits['msg_type'],
      msg_id: inits['msg_id'],
      mode: inits['mode'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(1 + 1 + 1);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint8(offset, msg_type);
    offset += 1;
    data.setUint8(offset, msg_id);
    offset += 1;
    data.setUint8(offset, mode);
    offset += 1;
    return bytes;
  }
}

class CmdName {
  final int msg_type;
  final int msg_id;
  final String uid;
  final String name;

  CmdName({
    required this.msg_type,
    required this.msg_id,
    required this.uid,
    required this.name,
  });

  factory CmdName.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['msg_type'] = data.getUint8(offset);
    offset += 1;
    inits['msg_id'] = data.getUint8(offset);
    offset += 1;
    inits['uid'] = String.fromCharCodes(bytes.sublist(offset, offset + IMB_UID_LEN)).split('\x00')[0];
    offset += IMB_UID_LEN;
    inits['name'] = String.fromCharCodes(bytes.sublist(offset, offset + IMB_NAME_LEN)).split('\x00')[0];
    offset += IMB_NAME_LEN;
    return CmdName(
      msg_type: inits['msg_type'],
      msg_id: inits['msg_id'],
      uid: inits['uid'],
      name: inits['name'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(1 + 1 + IMB_UID_LEN + IMB_NAME_LEN);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint8(offset, msg_type);
    offset += 1;
    data.setUint8(offset, msg_id);
    offset += 1;
    var uidBytes = Uint8List.fromList(uid.codeUnits);
    for (var i = 0; i < uidBytes.length && i < IMB_UID_LEN; i++) {
      bytes[offset + i] = uidBytes[i];
    }
    offset += IMB_UID_LEN;
    var nameBytes = Uint8List.fromList(name.codeUnits);
    for (var i = 0; i < nameBytes.length && i < IMB_NAME_LEN; i++) {
      bytes[offset + i] = nameBytes[i];
    }
    offset += IMB_NAME_LEN;
    return bytes;
  }
}

class CmdAccept {
  final int msg_type;
  final int msg_id;
  final String uid;
  final int accepted;

  CmdAccept({
    required this.msg_type,
    required this.msg_id,
    required this.uid,
    required this.accepted,
  });

  factory CmdAccept.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['msg_type'] = data.getUint8(offset);
    offset += 1;
    inits['msg_id'] = data.getUint8(offset);
    offset += 1;
    inits['uid'] = String.fromCharCodes(bytes.sublist(offset, offset + IMB_UID_LEN)).split('\x00')[0];
    offset += IMB_UID_LEN;
    inits['accepted'] = data.getUint8(offset);
    offset += 1;
    return CmdAccept(
      msg_type: inits['msg_type'],
      msg_id: inits['msg_id'],
      uid: inits['uid'],
      accepted: inits['accepted'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(1 + 1 + IMB_UID_LEN + 1);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint8(offset, msg_type);
    offset += 1;
    data.setUint8(offset, msg_id);
    offset += 1;
    var uidBytes = Uint8List.fromList(uid.codeUnits);
    for (var i = 0; i < uidBytes.length && i < IMB_UID_LEN; i++) {
      bytes[offset + i] = uidBytes[i];
    }
    offset += IMB_UID_LEN;
    data.setUint8(offset, accepted);
    offset += 1;
    return bytes;
  }
}

class Adv {
  final int company_id;
  final int pin_hash;
  final int op_mode;
  final int mesh_epoch;

  Adv({
    required this.company_id,
    required this.pin_hash,
    required this.op_mode,
    required this.mesh_epoch,
  });

  factory Adv.fromBytes(Uint8List bytes) {
    var offset = 0;
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    Map<String, dynamic> inits = {};
    inits['company_id'] = data.getUint16(offset, Endian.little);
    offset += 2;
    inits['pin_hash'] = data.getUint32(offset, Endian.little);
    offset += 4;
    inits['op_mode'] = data.getUint8(offset);
    offset += 1;
    inits['mesh_epoch'] = data.getUint8(offset);
    offset += 1;
    return Adv(
      company_id: inits['company_id'],
      pin_hash: inits['pin_hash'],
      op_mode: inits['op_mode'],
      mesh_epoch: inits['mesh_epoch'],
    );
  }

  Uint8List toBytes() {
    var bytes = Uint8List(2 + 4 + 1 + 1);
    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    var offset = 0;
    data.setUint16(offset, company_id, Endian.little);
    offset += 2;
    data.setUint32(offset, pin_hash, Endian.little);
    offset += 4;
    data.setUint8(offset, op_mode);
    offset += 1;
    data.setUint8(offset, mesh_epoch);
    offset += 1;
    return bytes;
  }
}
