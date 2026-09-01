import 'dart:async';

import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/firebase_chat_service.dart';
import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  Timer? _pollTimer;
  bool _isLoading = false;
  bool _isSending = false;
  List<ChatRoom> _rooms = [];
  List<Map<String, dynamic>> _users = [];
  List<ChatMessage> _messages = [];
  ChatRoom? _activeRoom;

  Map<String, dynamic> get _user => MobileApiService.currentUser ?? {};
  String get _userId => _user['user_id']?.toString() ?? _user['id']?.toString() ?? '';
  String get _userRole => _user['role']?.toString() ?? '';
  String get _userName {
    final name = [
      _user['first_name']?.toString(),
      _user['last_name']?.toString(),
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
    return name.isEmpty ? 'SK 360 User' : name;
  }

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _loadUsers();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeName = _activeRoom?.displayNameFor(_userName) ?? 'No conversation';

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PresidentSideDrawer(),
      backgroundColor: AppColors.lightGrayBg,
      bottomNavigationBar: PresidentBottomNavBar(
        activeItem: PresidentNavItem.chat,
        onItemSelected: _handleNavSelection,
      ),
      body: SafeArea(
        child: Column(
          children: [
            PresidentHeader(
              leading: PresidentHeaderLeading.menu,
              onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
              title: 'Chat',
              subtitle: 'Synced with web chat',
              trailing: [
                IconButton(
                  onPressed: _isLoading ? null : _refresh,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
            if (_isLoading) const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 132,
                    child: _RoomRail(
                      rooms: _rooms,
                      users: _users,
                      activeRoom: _activeRoom,
                      currentUserName: _userName,
                      searchController: _searchController,
                      onSearch: _loadUsers,
                      onRoomTap: _openRoom,
                      onUserTap: _openUser,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _ChatTitle(name: activeName),
                        Expanded(
                          child: _messages.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Select a user to start chatting.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.lightText),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(14),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) => _MessageBubble(
                                    message: _messages[index],
                                    own: _messages[index].senderId == _userId,
                                  ),
                                ),
                        ),
                        _Composer(
                          controller: _messageController,
                          enabled: _activeRoom != null && !_isSending,
                          onSend: _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    await _loadRooms();
    if (_activeRoom != null) await _loadMessages(_activeRoom!);
  }

  Future<void> _loadRooms() async {
    if (_userId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final rooms = await FirebaseChatService.roomsForUser(_userId);
      if (!mounted) return;
      setState(() => _rooms = rooms);
      if (_activeRoom == null && rooms.isNotEmpty) {
        await _openRoom(rooms.first);
      }
    } on ChatException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsers([String search = '']) async {
    try {
      final users = await MobileApiService.chatUsers(search: search);
      if (mounted) setState(() => _users = users);
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    }
  }

  Future<void> _openUser(Map<String, dynamic> user) async {
    setState(() => _isLoading = true);
    try {
      final room = await FirebaseChatService.ensureDirectRoom(
        currentUserId: _userId,
        currentUserName: _userName,
        otherUserId: user['id'].toString(),
        otherUserName: user['name'].toString(),
      );
      if (!mounted) return;
      if (!_rooms.any((item) => item.id == room.id)) {
        setState(() => _rooms = [room, ..._rooms]);
      }
      await _openRoom(room);
    } on ChatException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openRoom(ChatRoom room) async {
    _pollTimer?.cancel();
    setState(() => _activeRoom = room);
    await _loadMessages(room);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadMessages(room, quiet: true),
    );
  }

  Future<void> _loadMessages(ChatRoom room, {bool quiet = false}) async {
    try {
      final messages = await FirebaseChatService.messages(room.id);
      if (mounted) setState(() => _messages = messages);
    } on ChatException catch (exception) {
      if (!quiet && mounted) _showMessage(exception.message);
    }
  }

  Future<void> _sendMessage() async {
    final room = _activeRoom;
    final text = _messageController.text.trim();
    if (room == null || text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await FirebaseChatService.sendMessage(
        roomId: room.id,
        text: text,
        senderId: _userId,
        senderName: _userName,
        senderRole: _userRole,
      );
      _messageController.clear();
      await _loadMessages(room);
    } on ChatException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _handleNavSelection(PresidentNavItem item) {
    if (item == PresidentNavItem.chat) return;
    handleRoleNavSelection(context, item);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed),
    );
  }
}

class _RoomRail extends StatelessWidget {
  final List<ChatRoom> rooms;
  final List<Map<String, dynamic>> users;
  final ChatRoom? activeRoom;
  final String currentUserName;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final ValueChanged<ChatRoom> onRoomTap;
  final ValueChanged<Map<String, dynamic>> onUserTap;

  const _RoomRail({
    required this.rooms,
    required this.users,
    required this.activeRoom,
    required this.currentUserName,
    required this.searchController,
    required this.onSearch,
    required this.onRoomTap,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Search',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          if (searchController.text.trim().isNotEmpty)
            ...users.map((user) => _UserTile(user: user, onTap: () => onUserTap(user)))
          else
            ...rooms.map(
              (room) => _RoomTile(
                name: room.displayNameFor(currentUserName),
                active: room.id == activeRoom?.id,
                onTap: () => onRoomTap(room),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final String name;
  final bool active;
  final VoidCallback onTap;

  const _RoomTile({required this.name, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      selected: active,
      selectedTileColor: AppColors.softPink,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.primaryRed,
        child: Text(_initials(name), style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? 'User';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFF22C55E),
        child: Text(_initials(name), style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(user['role']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

class _ChatTitle extends StatelessWidget {
  final String name;

  const _ChatTitle({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: Text(
        name,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool own;

  const _MessageBubble({required this.message, required this.own});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: own ? AppColors.primaryRed : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: own ? null : Border.all(color: const Color(0xFFECEFF3)),
        ),
        child: Column(
          crossAxisAlignment: own ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.senderName,
              style: TextStyle(
                color: own ? Colors.white70 : AppColors.lightText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.text,
              style: TextStyle(color: own ? Colors.white : AppColors.darkGray),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final value = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return value.isEmpty ? 'U' : value;
}
