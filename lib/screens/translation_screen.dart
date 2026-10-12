import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'one_way_translation_screen.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final AuthService _auth = AuthService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF03A9F4);
    
    // Hàm lấy chữ cái đầu an toàn tuyệt đối
    String getInitial() {
      String name = currentUser?.displayName ?? '';
      if (name.trim().isEmpty) name = currentUser?.email ?? '';
      if (name.trim().isEmpty) return 'U';
      String trimmed = name.trim();
      return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : 'U';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // 1. Sidebar (Menu bên trái)
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FBFC),
              border: Border(right: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo Section
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
                      const Text(
                        'GoTrans',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.keyboard_tab, color: Colors.grey.shade400, size: 20),
                    ],
                  ),
                ),
                
                // Menu List
                SidebarItem(
                  index: 0,
                  icon: Icons.chat_bubble_outline,
                  title: 'Dịch một chiều',
                  isActive: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                SidebarItem(
                  index: 1,
                  icon: Icons.swap_horiz,
                  title: 'Dịch hai chiều',
                  isActive: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                SidebarItem(
                  index: 2,
                  icon: Icons.mic_none,
                  title: 'Phiên âm',
                  isActive: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                SidebarItem(
                  index: 3,
                  icon: Icons.event_available_outlined,
                  title: 'Chế độ sự kiện',
                  isActive: _selectedIndex == 3,
                  hasBadge: true,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
                
                const SizedBox(height: 20),
                SidebarItem(
                  index: 4,
                  icon: Icons.search,
                  title: 'Tìm kiếm',
                  isActive: _selectedIndex == 4,
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
                SidebarItem(
                  index: 5,
                  icon: Icons.history,
                  title: 'Lịch sử',
                  isActive: _selectedIndex == 5,
                  onTap: () => setState(() => _selectedIndex = 5),
                ),
                
                const Spacer(),
                
                // Promo Card (Blue Theme)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryBlue.withOpacity(0.7), primaryBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mới trên GoTrans',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Dịch giọng nói nhanh hơn, chính xác hơn',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'GoTransVoice',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                        const Text(
                          'Chuyển văn bản thành giọng nói & nhân bản giọng AI...',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'Truy cập GoTransVoice →',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // User Profile Section
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF94A3B8),
                        radius: 20,
                        child: Text(
                          getInitial(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  currentUser?.displayName ?? 'Người dùng',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Gói Miễn phí', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                ),
                              ],
                            ),
                            Text(
                              currentUser?.email ?? '',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 18, color: Colors.grey),
                        onPressed: () async => await _auth.signOut(),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 20),
                  child: Text('Sản phẩm đến từ GoTrans', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ),
              ],
            ),
          ),
          
          // 2. Main Content
          Expanded(
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Bạn muốn tạo gì hôm nay?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'AI giọng nói đa ngôn ngữ theo thời gian thực cho mục đích sử dụng hàng ngày',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 80),
                      
                      // Feature Cards row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FeatureCard(
                                icon: Icons.translate,
                                title: 'Dịch một chiều',
                                desc: 'Dịch cho các hội nghị hoặc hội thảo để mọi người cùng có thể theo dõi',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const OneWayTranslationScreen()),
                                  );
                                },
                              ),
                              const SizedBox(width: 20),
                              const FeatureCard(
                                icon: Icons.swap_horiz,
                                title: 'Dịch hai chiều',
                                desc: 'Hoàn hảo cho các cuộc họp hoặc trò chuyện nhóm bằng nhiều ngôn ngữ',
                              ),
                              const SizedBox(width: 20),
                              const FeatureCard(
                                icon: Icons.mic_none,
                                title: 'Phiên âm',
                                desc: 'GoTrans ghi lại từ thuật ngữ kỹ thuật đến quyết định quan trọng trong một bản phiên âm',
                              ),
                              const SizedBox(width: 20),
                              const FeatureCard(
                                icon: Icons.event_note,
                                title: 'Chế độ sự kiện',
                                desc: 'Phát bài phát biểu của bạn cho nhiều người tham dự qua QR với phụ đề trực tiếp',
                                isNew: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
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

  const SidebarItem({
    super.key,
    required this.index,
    required this.icon,
    required this.title,
    required this.isActive,
    required this.onTap,
    this.hasBadge = false,
  });

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
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            // Màu xám nhạt khi trỏ chuột vào (F1F5F9 là xám nhạt của Tailwind)
            color: widget.isActive 
                ? Colors.white 
                : (_isHovered ? const Color(0xFFF1F5F9) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.isActive 
                ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))] 
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon, 
                color: widget.isActive ? primaryBlue : const Color(0xFF64748B), 
                size: 22
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: widget.isActive ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                    fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (widget.hasBadge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: const Text(
                    'Mới', 
                    style: TextStyle(color: primaryBlue, fontSize: 10, fontWeight: FontWeight.bold)
                  ),
                ),
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

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.desc,
    this.isNew = false,
    this.onTap,
  });

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
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 250,
          height: 280,
          padding: const EdgeInsets.all(32),
          // Hiệu ứng đẩy ô lên nhẹ nhàng hơn và xoay nhẹ
          transform: _isHovered 
              ? (Matrix4.identity()
                  ..translate(0, -8) // Giảm từ -15 xuống -8
                  ..rotateZ(0.02))   // Giảm từ 0.05 xuống 0.02 (~1.1 độ)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FBFC),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: _isHovered ? primaryBlue.withOpacity(0.3) : Colors.grey.shade100,
              width: 1,
            ),
            // Hiệu ứng màu thu gọn lại hơn ở góc trên bên phải
            gradient: _isHovered
                ? RadialGradient(
                    center: const Alignment(1.2, -1.2), 
                    radius: 0.6,
                    colors: [
                      primaryBlue.withOpacity(0.18),
                      const Color(0xFFF9FBFC),
                    ],
                    stops: const [0.0, 1.0],
                  )
                : null,
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isHovered ? Colors.white : primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _isHovered 
                          ? [BoxShadow(color: primaryBlue.withOpacity(0.15), blurRadius: 8)] 
                          : null,
                    ),
                    child: Icon(widget.icon, color: primaryBlue, size: 24),
                  ),
                  if (widget.isNew)
                    Text(
                      'Mới',
                      style: TextStyle(
                        color: _isHovered ? primaryBlue : Colors.grey.shade400,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  widget.desc,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
