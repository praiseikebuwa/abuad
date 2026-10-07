import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalScreen extends StatefulWidget {
  final String title;
  final String markdownPath; // e.g., 'assets/legal/privacy_policy.md'
  const LegalScreen({
    super.key,
    required this.title,
    required this.markdownPath,
  });

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  String? _content;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final data = await rootBundle.loadString(widget.markdownPath);
      setState(() {
        _content = data;
        _isLoading = false;
      });
    } catch (e) {
      // Fallback to templates if asset not found
      setState(() {
        _content = widget.title == 'Privacy Policy'
            ? _getPrivacyPolicyTemplate()
            : _getTermsOfServiceTemplate();
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.white.withValues(alpha: 0.2),
            height: 1,
          ),
        ),
      ),
      body: _buildBody(textColor, isDark),
    );
  }

  Widget _buildBody(Color textColor, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _content == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Failed to load content. Please try again later.',
            style: GoogleFonts.outfit(fontSize: 16, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Markdown(
          data: _content!,
          styleSheet: MarkdownStyleSheet(
            h1: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.3,
            ),
            h2: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.4,
            ),
            h3: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textColor,
              height: 1.4,
            ),
            p: GoogleFonts.outfit(
              fontSize: 15,
              height: 1.6,
              color: textColor.withValues(alpha: 0.85),
            ),
            strong: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 4,
                ),
              ),
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            ),
            blockquotePadding: const EdgeInsets.all(12),
            codeblockDecoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            horizontalRuleDecoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            listBullet: GoogleFonts.outfit(fontSize: 15, color: textColor),
            // Additional spacing between elements
            a: GoogleFonts.outfit(
              color: Theme.of(context).primaryColor,
              decoration: TextDecoration.underline,
            ),
          ),
          physics: const BouncingScrollPhysics(),
        ),
      ),
    );
  }

  // Fallback templates (same as before, kept for completeness)
  String _getPrivacyPolicyTemplate() {
    return '''
# Privacy Policy for Abuad life

**Effective Date:** March 24, 2026

At Abuad life, we are committed to protecting your privacy. This Privacy Policy explains how we collect, use, and share information about you when you use our mobile application.

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
# Terms of Service for Abuad life

**Effective Date:** March 24, 2026

By using Abuad life, you agree to the following terms and conditions.

## 1. Eligibility
You must be a registered student, staff, or affiliate of Afe Babalola University to use this application.

## 2. User Conduct
- Do not post harmful, offensive, or illegal content.
- Respect the privacy of other students.
- Do not attempt to bypass security measures.

## 3. Disclaimers
Abuad life is provided "as is." We do not guarantee uninterrupted service or complete accuracy of campus data (e.g., shuttle locations).

## 4. Modifications
We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of new terms.
''';
  }
}
