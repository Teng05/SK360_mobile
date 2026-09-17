import 'dart:convert';
import 'dart:io';

class FirebaseChatService {
  static const String _projectId = 'sk360chat';
  static const String _apiKey = 'AIzaSyAxzGOnsSKoapk_PPNdD-A-48JlwNTkNrw';
  static const String _base =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  static Future<List<ChatRoom>> roomsForUser(String userId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [
          {'collectionId': 'chat_rooms'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'memberIds'},
            'op': 'ARRAY_CONTAINS',
            'value': {'stringValue': userId},
          },
        },
        'limit': 50,
      },
    });

    final rooms = docs.map(ChatRoom.fromDocument).toList();
    rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rooms;
  }

  static Future<ChatRoom> ensureDirectRoom({
    required String currentUserId,
    required String currentUserName,
    required String otherUserId,
    required String otherUserName,
  }) async {
    final roomKey = _roomKey(currentUserId, otherUserId);
    final existing = await _runQuery({
      'structuredQuery': {
        'from': [
          {'collectionId': 'chat_rooms'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'roomKey'},
            'op': 'EQUAL',
            'value': {'stringValue': roomKey},
          },
        },
        'limit': 1,
      },
    });

    if (existing.isNotEmpty) return ChatRoom.fromDocument(existing.first);

    await _postDocument('chat_rooms', {
      'name': _string(otherUserName),
      'type': _string('direct'),
      'createdBy': _string(currentUserId),
      'createdAt': _timestamp(DateTime.now()),
      'memberIds': _array([_string(currentUserId), _string(otherUserId)]),
      'memberNames': _array([_string(currentUserName), _string(otherUserName)]),
      'roomKey': _string(roomKey),
    });

    final created = await _runQuery({
      'structuredQuery': {
        'from': [
          {'collectionId': 'chat_rooms'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'roomKey'},
            'op': 'EQUAL',
            'value': {'stringValue': roomKey},
          },
        },
        'limit': 1,
      },
    });

    if (created.isEmpty) {
      throw const ChatException('Unable to create conversation room.');
    }

    return ChatRoom.fromDocument(created.first);
  }

  static Future<ChatRoom> createGroupRoom({
    required String name,
    required String currentUserId,
    required String currentUserName,
    required List<Map<String, String>> members,
  }) async {
    final allMembers = [
      ...members,
      {'id': currentUserId, 'name': currentUserName},
    ];
    final memberIds = allMembers.map((member) => member['id']!).toSet().toList();
    final memberNames = allMembers
        .fold<Map<String, String>>({}, (names, member) {
          names[member['id']!] = member['name']!;
          return names;
        })
        .values
        .toList();

    final created = await _postDocument('chat_rooms', {
      'name': _string(name),
      'type': _string('group'),
      'groupKind': _string('custom'),
      'createdBy': _string(currentUserId),
      'createdAt': _timestamp(DateTime.now()),
      'memberIds': _array(memberIds.map(_string).toList()),
      'memberNames': _array(memberNames.map(_string).toList()),
    });

    return ChatRoom.fromDocument(created);
  }

  static Future<List<ChatMessage>> messages(String roomId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [
          {'collectionId': 'chat_messages'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'roomId'},
            'op': 'EQUAL',
            'value': {'stringValue': roomId},
          },
        },
        'orderBy': [
          {
            'field': {'fieldPath': 'createdAt'},
            'direction': 'ASCENDING',
          },
        ],
        'limit': 100,
      },
    });

    return docs.map(ChatMessage.fromDocument).toList();
  }

  static Future<void> sendMessage({
    required String roomId,
    required String text,
    required String senderId,
    required String senderName,
    required String senderRole,
  }) async {
    await _postDocument('chat_messages', {
      'roomId': _string(roomId),
      'text': _string(text),
      'senderId': _string(senderId),
      'senderName': _string(senderName),
      'senderRole': _string(senderRole),
      'createdAt': _timestamp(DateTime.now()),
    });
  }

  static Future<List<Map<String, dynamic>>> _runQuery(
    Map<String, dynamic> body,
  ) async {
    final response = await _request(
      'POST',
      '$_base:runQuery?key=$_apiKey',
      body: body,
    );
    final rows = jsonDecode(response) as List<dynamic>;
    return rows
        .whereType<Map>()
        .map((row) => row['document'])
        .whereType<Map>()
        .map((doc) => Map<String, dynamic>.from(doc))
        .toList();
  }

  static Future<Map<String, dynamic>> _postDocument(
    String collection,
    Map<String, dynamic> fields,
  ) async {
    final response = await _request(
      'POST',
      '$_base/$collection?key=$_apiKey',
      body: {'fields': fields},
    );
    return Map<String, dynamic>.from(jsonDecode(response) as Map);
  }

  static Future<String> _request(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse(url));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ChatException(_extractError(text));
      }
      return text;
    } on SocketException {
      throw const ChatException('Cannot reach Firebase chat.');
    } finally {
      client.close(force: true);
    }
  }

  static String _extractError(String text) {
    try {
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      return decoded['error']?['message']?.toString() ?? 'Chat request failed.';
    } catch (_) {
      return 'Chat request failed.';
    }
  }

  static String _roomKey(String first, String second) {
    final ids = [first, second]..sort();
    return ids.join('_');
  }

  static Map<String, dynamic> _string(String value) => {'stringValue': value};

  static Map<String, dynamic> _timestamp(DateTime value) => {
    'timestampValue': value.toUtc().toIso8601String(),
  };

  static Map<String, dynamic> _array(List<Map<String, dynamic>> values) => {
    'arrayValue': {'values': values},
  };
}

class ChatRoom {
  final String id;
  final String name;
  final String type;
  final List<String> memberIds;
  final List<String> memberNames;
  final DateTime createdAt;

  const ChatRoom({
    required this.id,
    required this.name,
    required this.type,
    required this.memberIds,
    required this.memberNames,
    required this.createdAt,
  });

  factory ChatRoom.fromDocument(Map<String, dynamic> doc) {
    final fields = Map<String, dynamic>.from(doc['fields'] as Map? ?? {});
    return ChatRoom(
      id: doc['name'].toString().split('/').last,
      name: _fieldString(fields['name']),
      type: _fieldString(fields['type']),
      memberIds: _fieldArray(fields['memberIds']),
      memberNames: _fieldArray(fields['memberNames']),
      createdAt: DateTime.tryParse(_fieldTimestamp(fields['createdAt'])) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String displayNameFor(String currentUserName) {
    if (type == 'group') return name.isEmpty ? 'Group Chat' : name;
    final other = memberNames.firstWhere(
      (name) => name != currentUserName,
      orElse: () => name,
    );
    return other.isEmpty ? 'Direct Chat' : other;
  }
}

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String senderRole;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.createdAt,
  });

  factory ChatMessage.fromDocument(Map<String, dynamic> doc) {
    final fields = Map<String, dynamic>.from(doc['fields'] as Map? ?? {});
    return ChatMessage(
      id: doc['name'].toString().split('/').last,
      text: _fieldString(fields['text']),
      senderId: _fieldString(fields['senderId']),
      senderName: _fieldString(fields['senderName']),
      senderRole: _fieldString(fields['senderRole']),
      createdAt: DateTime.tryParse(_fieldTimestamp(fields['createdAt'])) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ChatException implements Exception {
  final String message;

  const ChatException(this.message);

  @override
  String toString() => message;
}

String _fieldString(Object? field) {
  if (field is Map && field['stringValue'] != null) {
    return field['stringValue'].toString();
  }
  return '';
}

String _fieldTimestamp(Object? field) {
  if (field is Map && field['timestampValue'] != null) {
    return field['timestampValue'].toString();
  }
  return '';
}

List<String> _fieldArray(Object? field) {
  if (field is! Map) return [];
  final array = field['arrayValue'];
  if (array is! Map) return [];
  final values = array['values'];
  if (values is! List) return [];
  return values.map(_fieldString).where((value) => value.isNotEmpty).toList();
}
