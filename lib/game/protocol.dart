import 'dart:convert';
import 'dart:typed_data';

const protocolVersion = 1;
const maxFrame = 262144;
Uint8List encodeFrame(Map<String, dynamic> message) {
  final data = utf8.encode(jsonEncode(message));
  if (data.isEmpty || data.length > maxFrame) {
    throw const FormatException('消息过长');
  }
  final header = ByteData(4)..setUint32(0, data.length, Endian.big);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...data]);
}

/// TCP/RFCOMM 字节流解码器；支持一帧多包、多帧一包。断线丢弃残帧。
class FrameDecoder {
  List<int> _buffer = [];
  bool closed = false;
  List<Map<String, dynamic>> feed(List<int> bytes) {
    if (closed) throw StateError('连接已关闭');
    _buffer.addAll(bytes);
    final out = <Map<String, dynamic>>[];
    while (_buffer.length >= 4) {
      final n = ByteData.sublistView(
        Uint8List.fromList(_buffer.take(4).toList()),
      ).getUint32(0, Endian.big);
      if (n == 0 || n > maxFrame) {
        close();
        throw const FormatException('非法帧长度');
      }
      if (_buffer.length < 4 + n) break;
      final raw = utf8.decode(_buffer.sublist(4, 4 + n));
      _buffer = _buffer.sublist(4 + n);
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) throw const FormatException('非法消息');
      out.add(map);
    }
    return out;
  }

  void close() {
    _buffer = [];
    closed = true;
  }
}

/// 意图含版本、会话代号和递增序号，拒绝旧局重放与重复消息。
class IntentGuard {
  final String session;
  final Map<String, int> _last = {};
  IntentGuard(this.session);
  void resetPeer(String peer) {
    _last.remove(peer);
  }

  bool accept(String peer, Map<String, dynamic> m) {
    final seq = m['seq'];
    if (m['v'] != protocolVersion ||
        m['session'] != session ||
        seq is! int ||
        seq <= (_last[peer] ?? 0)) {
      return false;
    }
    _last[peer] = seq;
    return true;
  }
}

class PeerDeadline {
  final Duration timeout;
  DateTime last;
  PeerDeadline(DateTime now, {this.timeout = const Duration(seconds: 30)})
    : last = now;
  void touch(DateTime now) {
    last = now;
  }

  bool expired(DateTime now) => now.difference(last) >= timeout;
}
