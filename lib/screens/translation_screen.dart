import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:record/record.dart';
import '../services/auth_service.dart';
import 'two_way_translation_screen.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final AuthService _auth = AuthService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  // 0: Dashboard, 1: Translation, 6: History
  int _selectedIndex = 0;
  int _previousIndex = 0;
  bool _isTwoWayMode = false; // Mặc định là một chiều vì sourceLang là Tự động

  final GlobalKey<TwoWayTranslationScreenState> _twoWayKey = GlobalKey<TwoWayTranslationScreenState>();

  final List<String> _historyItems = [];
  InputDevice? _selectedInputDevice;

  void _goToHistory() {
    setState(() {
      if (_selectedIndex != 6) {
        _previousIndex = _selectedIndex;
      }
      _selectedIndex = 6;
    });
  }

  void _goBackFromHistory() {
    setState(() {
      _selectedIndex = _previousIndex;
    });
  }

  void _handleNewChat() {
    if (_selectedIndex != 1) {
      setState(() {
        _selectedIndex = 1;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final summary = _twoWayKey.currentState?.currentConversationSummary ?? "";
      if (summary.isNotEmpty) _addToHistory(summary);
      _twoWayKey.currentState?.resetChat();
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã bắt đầu cuộc trò chuyện mới'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _addToHistory(String text) {
    if (text.isEmpty) return;
    setState(() {
      String summary = text.length > 40 ? "${text.substring(0, 40)}..." : text;
      if (!_historyItems.contains(summary)) {
        _historyItems.insert(0, summary);
      }
    });
  }

  void _loadFromHistory(String summary) {
    setState(() {
      _selectedIndex = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _twoWayKey.currentState?.loadConversation(summary);
    });
  }

  Future<void> _showAudioSettings() async {
    final twoWayState = _twoWayKey.currentState;
    if (twoWayState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng mở trang ${_isTwoWayMode ? "Dịch 2 chiều" : "Dịch một chiều"} trước để tải thiết bị.'))
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<InputDevice>>(
        future: twoWayState.getAvailableInputDevices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang tải danh sách thiết bị...'),
                ],
              ),
            );
          }

          final devices = snapshot.data ?? [];
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.settings_voice, color: Color(0xFF03A9F4)),
                SizedBox(width: 10),
                Text('Cài đặt âm thanh'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thiết bị thu âm (Microphone):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (devices.isEmpty)
                    const Text('Không tìm thấy thiết bị nào hoặc chưa cấp quyền.', style: TextStyle(color: Colors.red, fontSize: 12))
                  else
                    DropdownButtonFormField<InputDevice>(
                      isExpanded: true,
                      value: _selectedInputDevice,
                      hint: const Text('Chọn microphone'),
                      items: devices.map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.label, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedInputDevice = val);
                          twoWayState.setInputDevice(val);
                        }
                      },
                    ),
                  const SizedBox(height: 20),
                  const Text('Thiết bị phát âm (Speaker):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Sử dụng thiết bị đầu ra mặc định của hệ thống.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF03A9F4);
    final String translationModeTitle = _isTwoWayMode ? 'Dịch 2 chiều' : 'Dịch một chiều';
    
    String getInitial() {
      String name = currentUser?.displayName ?? '';
      if (name.trim().isEmpty) name = currentUser?.email ?? '';
      if (name.trim().isEmpty) return 'U';
      return name.trim()[0].toUpperCase();
    }

    int stackIndex = 0;
    if (_selectedIndex == 1) {
      stackIndex = 1;
    } else if (_selectedIndex == 6) {
      stackIndex = 2;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FBFC),
              border: Border(right: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setState(() => _selectedIndex = 0),
                        child: const Text(
                          'GoTrans',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // New Chat Button in Sidebar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleNewChat,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                          color: primaryBlue.withValues(alpha: 0.05),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: primaryBlue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Cuộc trò chuyện mới',
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                
                SidebarItem(
                  index: 0,
                  icon: Icons.chat_bubble_outline,
                  title: 'Trang chủ',
                  isActive: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                SidebarItem(
                  index: 1,
                  icon: Icons.swap_horiz,
                  title: translationModeTitle,
                  isActive: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                SidebarItem(index: 3, icon: Icons.mic_none, title: 'Phiên âm', isActive: _selectedIndex == 3, onTap: () {}),
                SidebarItem(index: 4, icon: Icons.event_available_outlined, title: 'Chế độ sự kiện', isActive: _selectedIndex == 4, hasBadge: true, onTap: () {}),
                
                const SizedBox(height: 20),
                SidebarItem(index: 5, icon: Icons.search, title: 'Tìm kiếm', isActive: _selectedIndex == 5, onTap: () {}),
                SidebarItem(
                  index: 6,
                  icon: Icons.history,
                  title: 'Lịch sử',
                  isActive: _selectedIndex == 6,
                  onTap: _goToHistory,
                ),

                // Recent History List in Sidebar
                if (_historyItems.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(28, 16, 16, 8),
                    child: Text(
                      'LỊCH SỬ GẦN ĐÂY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  ..._historyItems.take(3).map((item) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: InkWell(
                      onTap: () => _loadFromHistory(item),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.history, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
                ],
                
                const Spacer(),
                
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF94A3B8),
                        radius: 20,
                        child: Text(getInitial(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(currentUser?.displayName ?? 'Người dùng', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(currentUser?.email ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, size: 18, color: Colors.grey),
                        onPressed: _showAudioSettings,
                        tooltip: 'Cài đặt âm thanh',
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 18, color: Colors.grey),
                        onPressed: () async => await _auth.signOut(),
                        tooltip: 'Đăng xuất',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: IndexedStack(
              index: stackIndex,
              children: [
                _buildDashboard(translationModeTitle),
                TwoWayTranslationScreen(
                  key: _twoWayKey,
                  onHistoryAdded: _addToHistory,
                  onBack: () => setState(() => _selectedIndex = 0),
                  onNewChat: _handleNewChat,
                  onViewHistory: _goToHistory,
                  onLoadFromHistory: _loadFromHistory,
                  onModeChanged: (val) => setState(() => _isTwoWayMode = val),
                  historyItems: _historyItems,
                ),
                _buildHistoryScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryScreen() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 32, 40, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: _goBackFromHistory,
                  icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF64748B), size: 18),
                  style: IconButton.styleFrom(backgroundColor: Colors.white, shape: const CircleBorder(), side: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
                const SizedBox(width: 20),
                const Text('Lịch sử dịch thuật', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _historyItems.isEmpty
                  ? const Center(child: Text('Chưa có lịch sử nào'))
                  : ListView.builder(
                      itemCount: _historyItems.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(_historyItems[index]),
                          onTap: () => _loadFromHistory(_historyItems[index]),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(String translationModeTitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Bạn muốn tạo gì hôm nay?', textAlign: TextAlign.center, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 80),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FeatureCard(
                icon: Icons.swap_horiz,
                title: translationModeTitle,
                desc: 'Hoàn hảo cho các cuộc họp hoặc trò chuyện nhóm',
                onTap: () => setState(() => _selectedIndex = 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SidebarItem extends StatefulWidget {
  final int index;
  final IconData icon;
  final String title;
  final bool isActive;
  final bool hasBadge;
  final VoidCallback onTap;

  const SidebarItem({super.key, required this.index, required this.icon, required this.title, required this.isActive, required this.onTap, this.hasBadge = false});

  @override
  State<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF03A9F4);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isActive ? Colors.white : (_isHovered ? const Color(0xFFF1F5F9) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.isActive ? primaryBlue : const Color(0xFF64748B), size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.title, style: TextStyle(color: widget.isActive ? const Color(0xFF1E293B) : const Color(0xFF64748B), fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w500, fontSize: 14))),
              if (widget.hasBadge) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFE1F5FE), borderRadius: BorderRadius.circular(8)), child: const Text('Mới', style: TextStyle(color: primaryBlue, fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool isNew;
  final VoidCallback? onTap;

  const FeatureCard({super.key, required this.icon, required this.title, required this.desc, this.isNew = false, this.onTap});

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF03A9F4);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 250,
          height: 280,
          padding: const EdgeInsets.all(32),
          transform: _isHovered ? (Matrix4.translationValues(0, -10, 0)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FBFC),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: _isHovered ? primaryBlue.withValues(alpha: 0.3) : Colors.grey.shade100, width: 1),
            boxShadow: _isHovered ? [BoxShadow(color: primaryBlue.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 10))] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, color: primaryBlue, size: 24),
              const SizedBox(height: 28),
              Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              const SizedBox(height: 10),
              Text(widget.desc, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}