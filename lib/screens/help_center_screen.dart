import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I search for nearby teachers?',
      'answer': 'Go to the Search tab, grant location permission, and use the distance radius slider to find qualified teachers near your current location within your chosen kilometer range.'
    },
    {
      'question': 'How does the Diary Fee Management work?',
      'answer': 'Teachers can record monthly tuition fees and track student payment statuses (Paid, Due, Not Enrolled) in real-time. Deleting a diary record automatically recalculates total collected and outstanding dues instantly.'
    },
    {
      'question': 'How do secure chats and group classes work?',
      'answer': 'All chats and group batches are end-to-end encrypted. Teachers can post homework, quizzes, and polls, while students can ask academic doubts or leave batches voluntarily with complete privacy protection.'
    },
    {
      'question': 'Can I delete my account permanently?',
      'answer': 'Yes. You can request the permanent deletion of your account at any time by navigating to your profile, opening the More menu, and selecting "Delete Account Permanently".'
    },
    {
      'question': 'How do I switch between Teacher and Student roles?',
      'answer': 'Accounts are designated during registration based on your verified role. If you need assistance updating your account credentials or role, please contact our support team.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchEmailSupport() async {
    const String supportEmail = 'findyourbestteachertoday@gmail.com';
    final Uri emailUri = Uri.parse('mailto:$supportEmail?subject=Support%20Request%20-%20Find%20Your%20Best%20Teacher%20Today');
    
    try {
      bool launched = false;
      if (await canLaunchUrl(emailUri)) {
        launched = await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      }
      
      if (!launched) {
        await Clipboard.setData(const ClipboardData(text: supportEmail));
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('Email Support', style: TextStyle(fontWeight: FontWeight.bold, color: _primaryNavy)),
              content: const Text(
                'No email app was detected on this device.\n\nOur support email has been copied to your clipboard:\nfindyourbestteachertoday@gmail.com',
                style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      await Clipboard.setData(const ClipboardData(text: supportEmail));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email copied to clipboard: findyourbestteachertoday@gmail.com'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _faqs.where((faq) {
      if (_searchQuery.isEmpty) return true;
      return faq['question']!.toLowerCase().contains(_searchQuery) ||
          faq['answer']!.toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help Center & Support',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryNavy, _brandBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _primaryNavy.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // হেল্প সেন্টার আইকন: মানুষের মাথা ও হেডফোন পরা (Support Agent)
                  const Icon(Icons.support_agent_rounded, size: 54, color: Colors.cyanAccent),
                  const SizedBox(height: 10),
                  const Text(
                    'How can we help you today?',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Find answers to common questions or reach out to our developer support team directly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14, color: _primaryNavy),
                      decoration: InputDecoration(
                        hintText: 'Search questions, features, issues...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
                        prefixIcon: const Icon(Icons.search_rounded, color: _brandBlue, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
            if (filteredFaqs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No matching questions found.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
                  ),
                ),
              )
            else
              ...filteredFaqs.map((faq) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    collapsedIconColor: _brandBlue,
                    iconColor: _accentBlue,
                    title: Text(
                      faq['question']!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _primaryNavy,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faq['answer']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.mail_outline_rounded, color: _brandBlue, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Still need direct assistance?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'If you are experiencing any technical issue or account trouble, drop us an email and our developer team will respond promptly.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _launchEmailSupport();
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text(
                        'Email Support',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const Text(
                    'Find Your Best Teacher Today',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Version 1.0.0 • Developed by Md Imran Mondal',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
