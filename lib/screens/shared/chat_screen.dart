import 'dart:async';

import 'package:flutter/material.dart';

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
  bool _isLoadingUsers = false;
  bool _isSending = false;
  bool _showEmojiPicker = false;
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
    final isThreadOpen = _activeRoom != null;

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
              leading: isThreadOpen
                  ? PresidentHeaderLeading.back
                  : PresidentHeaderLeading.menu,
              onLeadingTap: isThreadOpen
                  ? _closeRoom
                  : () => _scaffoldKey.currentState?.openDrawer(),
              title: isThreadOpen ? activeName : 'Chat',
              subtitle: isThreadOpen ? 'Conversation' : 'Messages',
              trailing: isThreadOpen
                  ? null
                  : [
                      IconButton(
                        tooltip: 'Create group chat',
                        onPressed: _isLoading ? null : _createGroupChat,
                        icon: const Icon(
                          Icons.group_add_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
            ),
            if (_isLoading) const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: isThreadOpen
                  ? Column(
                      children: [
                        Expanded(
                          child: _messages.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No messages yet. Send a message to start chatting.',
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
                          enabled: !_isSending,
                          onSend: _sendMessage,
                          showEmojiPicker: _showEmojiPicker,
                          onToggleEmojiPicker: () => setState(
                            () => _showEmojiPicker = !_showEmojiPicker,
                          ),
                          onEmojiSelected: _insertEmoji,
                        ),
                      ],
                    )
                  : _RoomRail(
                      rooms: _rooms,
                      users: _users,
                      activeRoom: _activeRoom,
                      currentUserName: _userName,
                      currentUserId: _userId,
                      searchController: _searchController,
                      onSearch: _loadUsers,
                      onRoomTap: _openRoom,
                      onUserTap: _openUser,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRooms() async {
    if (_userId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final rooms = await FirebaseChatService.roomsForUser(_userId);
      if (!mounted) return;
      setState(() => _rooms = rooms);
    } on ChatException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsers([String search = '']) async {
    if (mounted) setState(() => _isLoadingUsers = true);
    try {
      final users = await MobileApiService.chatUsers(search: search);
      if (mounted) setState(() => _users = users);
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
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

  Future<void> _createGroupChat() async {
    final nameController = TextEditingController();
    final searchController = TextEditingController();
    final selectedIds = <String>{};
    var creating = false;
    String? error;

    final room = await showDialog<ChatRoom>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentId = _userId;
          final query = searchController.text.trim().toLowerCase();
          final candidates = _users.where((user) {
            final id = user['id']?.toString() ?? '';
            final name = user['name']?.toString() ?? '';
            final role = user['role']?.toString() ?? '';
            return id.isNotEmpty && id != currentId &&
                ('$name $role').toLowerCase().contains(query);
          }).toList();

          return AlertDialog(
            title: const Text('Create group chat'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    enabled: !creating,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Group name',
                      hintText: 'Enter a group name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchController,
                    enabled: !creating,
                    onChanged: (_) => setDialogState(() => error = null),
                    decoration: const InputDecoration(
                      labelText: 'Add members',
                      hintText: 'Search registered accounts',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'You are included automatically. Select at least one member.',
                      style: TextStyle(fontSize: 12, color: AppColors.lightText),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: _isLoadingUsers
                        ? const Center(child: CircularProgressIndicator())
                        : candidates.isEmpty
                        ? const Center(
                            child: Text('No matching registered accounts.'),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: candidates.length,
                            itemBuilder: (context, index) {
                              final user = candidates[index];
                              final id = user['id'].toString();
                              final isSelected = selectedIds.contains(id);
                              return CheckboxListTile(
                                value: isSelected,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(user['name']?.toString() ?? 'User'),
                                subtitle: Text(user['role']?.toString() ?? ''),
                                onChanged: creating
                                    ? null
                                    : (value) => setDialogState(() {
                                          if (value == true) {
                                            selectedIds.add(id);
                                          } else {
                                            selectedIds.remove(id);
                                          }
                                          error = null;
                                        }),
                              );
                            },
                          ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${selectedIds.length} selected'),
                  ),
                  if (error != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error!,
                        style: const TextStyle(color: AppColors.primaryRed),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: creating ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: creating
                    ? null
                    : () async {
                        final groupName = nameController.text.trim();
                        final selected = _users.where(
                          (user) => selectedIds.contains(user['id']?.toString()),
                        );
                        if (groupName.isEmpty || selectedIds.isEmpty) {
                          setDialogState(() {
                            error = 'Enter a group name and select at least one member.';
                          });
                          return;
                        }

                        setDialogState(() {
                          creating = true;
                          error = null;
                        });
                        try {
                          final createdRoom =
                              await FirebaseChatService.createGroupRoom(
                            name: groupName,
                            currentUserId: _userId,
                            currentUserName: _userName,
                            members: selected
                                .map((user) => {
                                      'id': user['id'].toString(),
                                      'name': user['name']?.toString() ?? 'User',
                                    })
                                .toList(),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, createdRoom);
                          }
                        } on ChatException catch (exception) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              creating = false;
                              error = exception.message;
                            });
                          }
                        }
                      },
                child: Text(creating ? 'Creating...' : 'Create group'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    searchController.dispose();
    if (!mounted || room == null) return;
    setState(() => _rooms = [room, ..._rooms.where((item) => item.id != room.id)]);
    await _openRoom(room);
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

  void _closeRoom() {
    _pollTimer?.cancel();
    setState(() {
      _activeRoom = null;
      _messages = [];
      _showEmojiPicker = false;
      _messageController.clear();
    });
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
      setState(() => _showEmojiPicker = false);
      await _loadMessages(room);
    } on ChatException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _insertEmoji(String emoji) {
    final value = _messageController.value;
    final start = value.selection.start < 0
        ? value.text.length
        : value.selection.start;
    final end = value.selection.end < 0 ? start : value.selection.end;
    final text = value.text.replaceRange(start, end, emoji);
    final cursor = start + emoji.length;
    _messageController.value = value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
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
  final String currentUserId;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final ValueChanged<ChatRoom> onRoomTap;
  final ValueChanged<Map<String, dynamic>> onUserTap;

  const _RoomRail({
    required this.rooms,
    required this.users,
    required this.activeRoom,
    required this.currentUserName,
    required this.currentUserId,
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
                profilePictureUrl: _roomPhoto(room),
                active: room.id == activeRoom?.id,
                onTap: () => onRoomTap(room),
              ),
            ),
        ],
      ),
    );
  }

  String? _roomPhoto(ChatRoom room) {
    final otherId = room.memberIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    for (final user in users) {
      if (user['id']?.toString() == otherId) {
        return user['profile_pic_url']?.toString();
      }
    }
    return null;
  }
}

class _RoomTile extends StatelessWidget {
  final String name;
  final String? profilePictureUrl;
  final bool active;
  final VoidCallback onTap;

  const _RoomTile({required this.name, required this.active, required this.onTap, this.profilePictureUrl});

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
        backgroundImage: profilePictureUrl?.isNotEmpty == true
            ? NetworkImage(profilePictureUrl!)
            : null,
        child: profilePictureUrl?.isNotEmpty == true
            ? null
            : Text(_initials(name), style: const TextStyle(color: Colors.white, fontSize: 11)),
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
        backgroundImage: user['profile_pic_url']?.toString().isNotEmpty == true
            ? NetworkImage(user['profile_pic_url'].toString())
            : null,
        child: user['profile_pic_url']?.toString().isNotEmpty == true
            ? null
            : Text(_initials(name), style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(user['role']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
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
  final bool showEmojiPicker;
  final VoidCallback onToggleEmojiPicker;
  final ValueChanged<String> onEmojiSelected;

  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.showEmojiPicker,
    required this.onToggleEmojiPicker,
    required this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          if (showEmojiPicker)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightGrayBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final emoji in const [
                    '\u{1F600}',
                    '\u{1F602}',
                    '\u{1F60D}',
                    '\u{1F64F}',
                    '\u{1F44D}',
                    '\u{1F389}',
                    '\u{2764}\u{FE0F}',
                    '\u{1F525}',
                    '\u{1F622}',
                    '\u{1F621}',
                    '\u{1F914}',
                    '\u{1F44F}',
                  ])
                    InkWell(
                      onTap: enabled ? () => onEmojiSelected(emoji) : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                onPressed: enabled ? onToggleEmojiPicker : null,
                color: AppColors.primaryRed,
                icon: Icon(
                  showEmojiPicker
                      ? Icons.close_rounded
                      : Icons.emoji_emotions_outlined,
                ),
              ),
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
