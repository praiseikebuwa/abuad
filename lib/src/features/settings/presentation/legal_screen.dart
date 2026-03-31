import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String
  markdownPath; // In a real app, this would be an asset path or URL

  const LegalScreen({
    super.key,
    required this.title,
    required this.markdownPath,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder markdown content since actual assets might not exist yet
    final String content = title == 'Privacy Policy'
        ? _getPrivacyPolicyTemplate()
        : _getTermsOfServiceTemplate();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Markdown(
        data: content,
        styleSheet: MarkdownStyleSheet(
          h1: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
          h2: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 2,
          ),
          p: GoogleFonts.outfit(fontSize: 14, height: 1.5),
        ),
      ),
    );
  }

  String _getPrivacyPolicyTemplate() {
    return '''
# Privacy Policy for ABUAD Nest

**Effective Date:** March 24, 2026

At ABUAD Nest, we are committed to protecting your privacy. This Privacy Policy explains how we collect, use, and share information about you when you use our mobile application.

## 1. Information We Collect
- **Account Information:** Name, email, and Student ID provided during signup.
- **Content:** Posts, comments, and messages you create.
- **Location:** Real-time location for features like Shuttle Tracker and SOS (only when active).

## 2. How We Use Information
- To provide and maintain our services.
- To notify you about changes to our service.
- To provide campus safety features.

## 3. Data Security
We use industry-standard security measures to protect your data. However, no method of transmission over the internet is 100% secure.

## 4. Contact Us
If you have questions, contact the ABUAD IT Department.
''';
  }

  String _getTermsOfServiceTemplate() {
    return '''
# Terms of Service for ABUAD Nest

**Effective Date:** March 24, 2026

By using ABUAD Nest, you agree to the following terms and conditions.

## 1. Eligibility
You must be a registered student, staff, or affiliate of Afe Babalola University to use this application.

## 2. User Conduct
- Do not post harmful, offensive, or illegal content.
- Respect the privacy of other students.
- Do not attempt to bypass security measures.

## 3. Disclaimers
ABUAD Nest is provided "as is." We do not guarantee uninterrupted service or complete accuracy of campus data (e.g., shuttle locations).

## 4. Modifications
We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of new terms.
''';
  }
}
