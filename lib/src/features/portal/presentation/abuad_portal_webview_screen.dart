import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../data/academic_repository.dart';

class AbuadPortalWebViewScreen extends ConsumerStatefulWidget {
  final String initialUrl;

  const AbuadPortalWebViewScreen({
    super.key,
    this.initialUrl = 'https://portal.abuad.edu.ng/PortalHome',
  });

  @override
  ConsumerState<AbuadPortalWebViewScreen> createState() =>
      _AbuadPortalWebViewScreenState();
}

class _AbuadPortalWebViewScreenState
    extends ConsumerState<AbuadPortalWebViewScreen> {
  late final WebViewController _controller;
  double _loadingProgress = 0.0;
  bool _isLoading = true;
  String _currentUrl = 'https://portal.abuad.edu.ng/PortalHome';
  bool _canGoBack = false;
  bool _canGoForward = false;

  // Credential State
  String _savedUsername = '';
  String _savedPassword = '';
  bool _autoSignInEnabled = true;
  bool _credentialsLoaded = false;
  bool _hasAttemptedAutoFill = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _initController();
    _loadStoredCredentials();
  }

  Future<void> _loadStoredCredentials() async {
    final repo = ref.read(academicRepositoryProvider);
    final creds = await repo.getPortalCredentials();
    if (mounted) {
      setState(() {
        _savedUsername = creds['username'] as String? ?? '';
        _savedPassword = creds['password'] as String? ?? '';
        _autoSignInEnabled = creds['autoSignIn'] as bool? ?? true;
        _credentialsLoaded = true;
      });
      // If page is already loaded and credentials became available
      if (!_isLoading && _savedUsername.isNotEmpty && _savedPassword.isNotEmpty && _autoSignInEnabled) {
        _injectAutoSignIn();
      }
    }
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress / 100);
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _currentUrl = url;
                _hasAttemptedAutoFill = false;
              });
              _updateNavButtons();
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _currentUrl = url;
              });
              _updateNavButtons();
            }
            if (_credentialsLoaded && _autoSignInEnabled && _savedUsername.isNotEmpty && _savedPassword.isNotEmpty) {
              _injectAutoSignIn();
            }
            _injectCredentialWatcher();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('ABUAD Portal Web Error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'AbuadPortalBridge',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            if (data is Map && data['username'] != null && data['password'] != null) {
              final u = data['username'].toString().trim();
              final p = data['password'].toString().trim();
              if (u.isNotEmpty && p.isNotEmpty && (u != _savedUsername || p != _savedPassword)) {
                _showSaveCredentialsPrompt(u, p);
              }
            }
          } catch (_) {}
        },
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _updateNavButtons() async {
    final back = await _controller.canGoBack();
    final forward = await _controller.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    }
  }

  /// Injects JavaScript to auto-fill username & password and trigger Sign In
  Future<void> _injectAutoSignIn() async {
    if (_savedUsername.isEmpty || _savedPassword.isEmpty || _hasAttemptedAutoFill) return;
    _hasAttemptedAutoFill = true;

    final escapedUser = jsonEncode(_savedUsername);
    final escapedPass = jsonEncode(_savedPassword);

    final script = '''
      (function() {
        try {
          var u = document.querySelector('input[name="username"], input[id="username"], input[placeholder*="Username" i], input[type="text"]');
          var p = document.querySelector('input[name="password"], input[id="password"], input[placeholder*="Password" i], input[type="password"]');
          var btn = document.querySelector('button[type="submit"], input[type="submit"], .btn-signin, button:has(i), a.btn-primary');

          if (u && p) {
            u.value = $escapedUser;
            p.value = $escapedPass;
            
            // Dispatch input and change events so frontend frameworks like Angular/React update their models
            u.dispatchEvent(new Event('input', { bubbles: true }));
            u.dispatchEvent(new Event('change', { bubbles: true }));
            p.dispatchEvent(new Event('input', { bubbles: true }));
            p.dispatchEvent(new Event('change', { bubbles: true }));

            if (btn) {
              setTimeout(function() {
                try {
                  btn.click();
                } catch(e) {}
              }, 400);
            }
          }
        } catch(e) {
          console.error('Auto-signin injection error:', e);
        }
      })();
    ''';

    try {
      await _controller.runJavaScript(script);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20),
                SizedBox(width: 8),
                Text('Auto-filled ABUAD Portal credentials!'),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error running auto sign-in JS: $e');
    }
  }

  /// Injects form listener to learn credentials when student logs in manually
  Future<void> _injectCredentialWatcher() async {
    const script = '''
      (function() {
        if (window._abuadWatcherActive) return;
        window._abuadWatcherActive = true;

        function checkAndNotify() {
          var u = document.querySelector('input[name="username"], input[id="username"], input[placeholder*="Username" i], input[type="text"]');
          var p = document.querySelector('input[name="password"], input[id="password"], input[placeholder*="Password" i], input[type="password"]');
          if (u && p && u.value && p.value) {
            try {
              AbuadPortalBridge.postMessage(JSON.stringify({
                username: u.value,
                password: p.value
              }));
            } catch(e) {}
          }
        }

        var forms = document.querySelectorAll('form');
        forms.forEach(function(f) {
          f.addEventListener('submit', function() {
            checkAndNotify();
          });
        });

        var buttons = document.querySelectorAll('button[type="submit"], input[type="submit"], .btn-signin, button:has(i)');
        buttons.forEach(function(b) {
          b.addEventListener('click', function() {
            setTimeout(checkAndNotify, 100);
          });
        });
      })();
    ''';
    try {
      await _controller.runJavaScript(script);
    } catch (_) {}
  }

  void _showSaveCredentialsPrompt(String username, String password) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.vpn_key_rounded, color: Colors.amberAccent),
            SizedBox(width: 10),
            Text('Save Portal Login?', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Would you like to save these credentials to auto-sign into the ABUAD e-Portal next time?',
              style: TextStyle(color: Colors.white70, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Matric / Username: $username', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Password: ••••••••••', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(academicRepositoryProvider).savePortalCredentials(
                username: username,
                password: password,
                autoSignIn: true,
              );
              setState(() {
                _savedUsername = username;
                _savedPassword = password;
                _autoSignInEnabled = true;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Portal credentials saved for 1-Tap Auto Sign-In!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save Credentials'),
          ),
        ],
      ),
    );
  }

  void _openCredentialVaultSheet() {
    final userController = TextEditingController(text: _savedUsername);
    final passController = TextEditingController(text: _savedPassword);
    bool autoSign = _autoSignInEnabled;
    bool obscurePass = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_person_rounded, color: AppColors.secondaryTeal, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Portal Credential Vault',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Auto-fill and auto-sign in to portal.abuad.edu.ng',
                          style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Username input
              TextField(
                controller: userController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Portal Username / Matric Number',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'e.g. 21/ENG02/089 or username',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.secondaryTeal),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Password input
              TextField(
                controller: passController,
                obscureText: obscurePass,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Portal Password',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.key_rounded, color: AppColors.secondaryTeal),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePass ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () => setSheetState(() => obscurePass = !obscurePass),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Auto-sign in toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.secondaryTeal,
                  title: Text(
                    'Enable Auto Sign-In',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Automatically submit credentials whenever the portal sign-in page is reached.',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                  ),
                  value: autoSign,
                  onChanged: (val) => setSheetState(() => autoSign = val),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  if (_savedUsername.isNotEmpty)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ref.read(academicRepositoryProvider).clearPortalCredentials();
                          setState(() {
                            _savedUsername = '';
                            _savedPassword = '';
                            _autoSignInEnabled = false;
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Portal credentials removed.')),
                            );
                          }
                        },
                        child: const Text('Clear'),
                      ),
                    ),
                  if (_savedUsername.isNotEmpty) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        'Save & Auto-Fill',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final u = userController.text.trim();
                        final p = passController.text.trim();
                        Navigator.pop(ctx);
                        await ref.read(academicRepositoryProvider).savePortalCredentials(
                          username: u,
                          password: p,
                          autoSignIn: autoSign,
                        );
                        setState(() {
                          _savedUsername = u;
                          _savedPassword = p;
                          _autoSignInEnabled = autoSign;
                          _hasAttemptedAutoFill = false;
                        });
                        _injectAutoSignIn();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToUrl(String url) {
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ABUAD Integrated e-Portal',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _savedUsername.isNotEmpty && _autoSignInEnabled
                        ? Colors.greenAccent
                        : Colors.amberAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _savedUsername.isNotEmpty && _autoSignInEnabled
                      ? 'Auto Sign-In Active ($_savedUsername)'
                      : 'portal.abuad.edu.ng',
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _savedUsername.isNotEmpty ? Icons.vpn_key_rounded : Icons.vpn_key_outlined,
              color: _savedUsername.isNotEmpty ? Colors.amberAccent : Colors.white70,
            ),
            tooltip: 'Credential Vault',
            onPressed: _openCredentialVaultSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Reload Page',
            onPressed: () {
              _hasAttemptedAutoFill = false;
              _controller.reload();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1E293B),
            onSelected: (val) async {
              switch (val) {
                case 'external':
                  final uri = Uri.parse(_currentUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  break;
                case 'vault':
                  _openCredentialVaultSheet();
                  break;
                case 'home':
                  _navigateToUrl('https://portal.abuad.edu.ng/PortalHome');
                  break;
                case 'transcript':
                  _navigateToUrl('https://portal.abuad.edu.ng/Transcript');
                  break;
                case 'calendar':
                  _navigateToUrl('https://portal.abuad.edu.ng/Calendar');
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'vault',
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded, color: Colors.amberAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Auto Sign-In Vault', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'home',
                child: Row(
                  children: [
                    Icon(Icons.home_rounded, color: Colors.blueAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Portal Home', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'transcript',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: Colors.purpleAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Transcript Portal', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'calendar',
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, color: Colors.greenAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Academic Calendar', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 8),
              const PopupMenuItem(
                value: 'external',
                child: Row(
                  children: [
                    Icon(Icons.open_in_browser_rounded, color: Colors.white70, size: 18),
                    SizedBox(width: 10),
                    Text('Open in Chrome/Browser', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Loading Progress Bar
          if (_isLoading)
            LinearProgressIndicator(
              value: _loadingProgress > 0 ? _loadingProgress : null,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondaryTeal),
              minHeight: 2.5,
            ),

          // Portal Quick Links Strip
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF090D16),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildQuickChip('e-Portal Home', 'https://portal.abuad.edu.ng/PortalHome', Icons.home_rounded),
                _buildQuickChip('Transcripts', 'https://portal.abuad.edu.ng/Transcript', Icons.school_rounded),
                _buildQuickChip('Events Calendar', 'https://portal.abuad.edu.ng/Calendar', Icons.event_note_rounded),
                _buildQuickChip('Lecturers', 'https://portal.abuad.edu.ng/Lecturers', Icons.people_alt_rounded),
                _buildQuickChip('ABUAD Website', 'https://abuad.edu.ng', Icons.language_rounded),
              ],
            ),
          ),

          // Browser View
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),

          // Browser Navigation Bottom Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _canGoBack ? Colors.white : Colors.white24),
                      onPressed: _canGoBack ? () => _controller.goBack() : null,
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: _canGoForward ? Colors.white : Colors.white24),
                      onPressed: _canGoForward ? () => _controller.goForward() : null,
                    ),
                  ],
                ),
                InkWell(
                  onTap: _openCredentialVaultSheet,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _savedUsername.isNotEmpty ? AppColors.secondaryTeal.withValues(alpha: 0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _savedUsername.isNotEmpty ? AppColors.secondaryTeal : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _savedUsername.isNotEmpty ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                          size: 14,
                          color: _savedUsername.isNotEmpty ? AppColors.secondaryTeal : Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _savedUsername.isNotEmpty ? '1-Tap Sign-In' : 'Save Credentials',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _savedUsername.isNotEmpty ? AppColors.secondaryTeal : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20, color: Colors.white70),
                  tooltip: 'Open in external browser',
                  onPressed: () async {
                    final uri = Uri.parse(_currentUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String url, IconData icon) {
    final isSelected = _currentUrl.contains(url);
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: ActionChip(
        avatar: Icon(
          icon,
          size: 14,
          color: isSelected ? Colors.white : AppColors.secondaryTeal,
        ),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white80,
          ),
        ),
        backgroundColor: isSelected ? AppColors.secondaryTeal : const Color(0xFF1E293B),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onPressed: () => _navigateToUrl(url),
      ),
    );
  }
}
