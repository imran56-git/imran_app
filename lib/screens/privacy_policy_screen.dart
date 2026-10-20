import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);

  @override
  Widget build(BuildContext context) {
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
          'Privacy Policy',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy - Find Your Best Teacher Today',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _primaryNavy,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Effective Date: March 31, 2026\nDeveloper: Md Imran Mondal\nContact Email: findyourbestteachertoday@gmail.com',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              Divider(height: 30, thickness: 1, color: Color(0xFFF1F5F9)),
              _PolicySection(
                title: '1. Introduction',
                content:
                    'Welcome to Find Your Best Teacher Today. We value your privacy and are committed to protecting your personal information. This application connects students with teachers based on subjects and location. By using our app, you agree to the terms outlined in this policy.',
              ),
              _PolicySection(
                title: '2. Information We Collect',
                content:
                    'To provide our services effectively, we collect the following types of information:\n\n• Personal Information: Name, email address, and profile details provided during registration.\n• Location Information: We access your device\'s current location to help find nearby teachers. Specifically, your location is used strictly to search for and display teachers within the kilometer radius or ratio selected by you in the app\'s search filters. This data is utilized only while the app is actively being used for search purposes.\n• Communication Data: Messages, images, or voice notes exchanged between users within the app\'s secure chat system.\n• Device Information: Device type, OS version, and app usage data to improve performance.',
              ),
              _PolicySection(
                title: '3. How We Use Your Information',
                content:
                    'We use the collected data to:\n\n• Display relevant teachers based on your subject requirements and the custom kilometer radius/ratio you select.\n• Enable secure communication between students and teachers.\n• Improve app functionality and provide a better user experience.\n• Send important notifications regarding account or app activity.',
              ),
              _PolicySection(
                title: '4. Third-Party Services',
                content:
                    'We use trusted third-party services to power essential features:\n\n• Google Firebase: For authentication, Firestore database, and Cloud Messaging.\n• Google Maps API: To provide location-based search and map features.\n• Firebase Cloud Storage: To store profile images and shared media files.\n\nNote: These services operate under their own privacy policies.',
              ),
              _PolicySection(
                title: '5. Data Sharing & Security',
                content:
                    '• We do not sell, rent, or share your personal data with third parties for marketing purposes.\n• Data is protected using industry-standard security practices and Firebase security tools.\n• Data is only shared with the essential services required to operate the app.',
              ),
              _PolicySection(
                title: '6. User Rights',
                content:
                    'Users have full control over their data:\n\n• You can update your profile information at any time within the app.\n• You may request the permanent deletion of your account and data by accessing the "Delete Account Permanently" option located under the More menu in your profile, or by emailing us directly.',
              ),
              _PolicySection(
                title: '7. Children’s Privacy',
                content:
                    'This app is not intended for children under the age of 13. We do not knowingly collect personal information from children. If discovered, such data will be deleted immediately.',
              ),
              _PolicySection(
                title: '8. Policy Updates',
                content:
                    'We may update this Privacy Policy from time to time. Any significant changes will be communicated through the app or updated on this page.',
              ),
              _PolicySection(
                title: '9. Contact Us',
                content:
                    'If you have any questions or concerns, please contact:\n\nDeveloper: Md Imran Mondal\nEmail: findyourbestteachertoday@gmail.com',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String content;

  const _PolicySection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E4C7A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF334155),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
