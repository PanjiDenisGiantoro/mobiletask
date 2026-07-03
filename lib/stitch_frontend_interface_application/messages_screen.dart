import 'package:flutter/material.dart';
import 'app_theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String _searchQuery = '';

  final List<Map<String, dynamic>> _chats = [
    {
      'name': 'Mobile App Redesign',
      'isGroup': true,
      'lastMessage': 'Andi: Wireframes sudah diupload ya guys',
      'time': '10:42',
      'unread': 3,
      'avatarColor': AppColors.info,
      'avatarIcon': Icons.phone_android,
    },
    {
      'name': 'Budi Santoso',
      'isGroup': false,
      'lastMessage': 'Oke siap, saya review sekarang',
      'time': '09:15',
      'unread': 0,
      'avatarColor': AppColors.success,
      'avatarIcon': null,
      'initials': 'BS',
    },
    {
      'name': 'Backend API v2',
      'isGroup': true,
      'lastMessage': 'Reza: Migration script sudah push ke repo',
      'time': 'Yesterday',
      'unread': 7,
      'avatarColor': AppColors.primary600,
      'avatarIcon': Icons.code,
    },
    {
      'name': 'Siti Rahma',
      'isGroup': false,
      'lastMessage': 'Boleh minta file desain-nya?',
      'time': 'Yesterday',
      'unread': 1,
      'avatarColor': AppColors.warning,
      'avatarIcon': null,
      'initials': 'SR',
    },
    {
      'name': 'Marketing Campaign Q2',
      'isGroup': true,
      'lastMessage': 'Dika: Report sudah dikirim ke klien',
      'time': 'Mon',
      'unread': 0,
      'avatarColor': AppColors.accent400,
      'avatarIcon': Icons.campaign,
    },
    {
      'name': 'Hendra Wijaya',
      'isGroup': false,
      'lastMessage': 'Thanks ya sudah dibantu!',
      'time': 'Mon',
      'unread': 0,
      'avatarColor': AppColors.error,
      'avatarIcon': null,
      'initials': 'HW',
    },
    {
      'name': 'Design Team',
      'isGroup': true,
      'lastMessage': 'Color palette final sudah di-update',
      'time': 'Sun',
      'unread': 0,
      'avatarColor': AppColors.primary400,
      'avatarIcon': Icons.palette,
    },
  ];

  List<Map<String, dynamic>> get _filtered => _chats
      .where((c) => c['name']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.heroStart,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.heroStart, AppColors.heroMid],
            ),
          ),
        ),
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildChatList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'messages_fab',
        onPressed: () {},
        backgroundColor: AppColors.heroStart,
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search messages...',
          hintStyle: const TextStyle(color: AppColors.grey400, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
          filled: true,
          fillColor: AppColors.grey100,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    final list = _filtered;
    if (list.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: AppColors.grey400),
            SizedBox(height: AppSpacing.sm),
            Text('No messages found',
                style: TextStyle(color: AppColors.grey700, fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 80,
        color: AppColors.grey100,
      ),
      itemBuilder: (_, i) => _buildChatTile(list[i]),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final hasUnread = (chat['unread'] as int) > 0;
    return InkWell(
      onTap: () {},
      child: Container(
        color: AppColors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        child: Row(
          children: [
            _buildAvatar(chat),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat['name'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AppColors.grey900,
                        ),
                      ),
                      Text(
                        chat['time'],
                        style: TextStyle(
                          fontSize: 11,
                          color: hasUnread
                              ? AppColors.heroStart
                              : AppColors.grey400,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat['lastMessage'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread
                                ? AppColors.grey900
                                : AppColors.grey700,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.heroStart,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '${chat['unread']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> chat) {
    final color = chat['avatarColor'] as Color;
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: chat['avatarIcon'] != null
              ? Icon(chat['avatarIcon'] as IconData, color: color, size: 24)
              : Center(
                  child: Text(
                    chat['initials'] ?? '',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
        ),
        if (chat['isGroup'] == false)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
