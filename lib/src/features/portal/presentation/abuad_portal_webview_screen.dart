import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  WebViewController? _controller;
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
  bool _obscureWebPassword = true;

  // Extracted Student Portal Data
  Map<String, dynamic>? _detectedPortalData;
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    if (!kIsWeb) {
      _initController();
    } else {
      _isLoading = false;
    }
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
      if (!kIsWeb && !_isLoading && _savedUsername.isNotEmpty && _savedPassword.isNotEmpty && _autoSignInEnabled) {
        _injectAutoSignIn();
      }
    }
  }

  void _initController() {
    if (kIsWeb) return;
    try {
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
            // Automatically scrape student profile & registered courses from portal DOM
            Future.delayed(const Duration(milliseconds: 900), () {
              if (mounted) _injectPortalDataExtractor();
            });
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
            if (data is Map) {
              if (data['type'] == 'PORTAL_DATA_SYNC') {
                final payload = Map<String, dynamic>.from(data['payload'] as Map? ?? {});
                _handleExtractedPortalData(payload);
              } else if (data['username'] != null && data['password'] != null) {
                final u = data['username'].toString().trim();
                final p = data['password'].toString().trim();
                if (u.isNotEmpty && p.isNotEmpty && (u != _savedUsername || p != _savedPassword)) {
                  _showSaveCredentialsPrompt(u, p);
                }
              }
            }
          } catch (_) {}
        },
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
    } catch (e) {
      debugPrint('Failed to initialize WebViewController: $e');
    }
  }

  Future<void> _updateNavButtons() async {
    if (kIsWeb || _controller == null) return;
    try {
      final back = await _controller?.canGoBack() ?? false;
      final forward = await _controller?.canGoForward() ?? false;
      if (mounted) {
        setState(() {
          _canGoBack = back;
          _canGoForward = forward;
        });
      }
    } catch (_) {}
  }

  /// Injects JavaScript to auto-fill username & password and trigger Sign In
  Future<void> _injectAutoSignIn() async {
    if (kIsWeb || _controller == null) return;
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
      await _controller?.runJavaScript(script);
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
      await _controller?.runJavaScript(script);
    } catch (_) {}
  }

  /// Extracts student profile, matriculation number, department, college, level, and courses from ABUAD portal DOM
  /// Extracts student profile, matriculation number, department, college, level, and courses from ABUAD portal DOM
  Future<void> _injectPortalDataExtractor({bool manual = false}) async {
    final script = '''
      (function() {
        try {
          var text = document.body ? document.body.innerText : '';
          
          // 1. Matric Number (e.g. 25/SCI01/057, 21/ENG02/089)
          var matricMatch = text.match(/\\b(\\d{2}\\/[A-Za-z0-9]{2,8}\\/\\d{2,5})\\b/);
          var matricNumber = matricMatch ? matricMatch[1].toUpperCase() : null;

          // 2. Full Name
          var fullName = null;

          // Check if inputs exist on UpdateProfile page (Surname, Firstname, Othername)
          var surnameInput = document.querySelector('input[name*="surname" i], input[id*="surname" i], input[placeholder*="Surname" i]');
          var firstnameInput = document.querySelector('input[name*="firstname" i], input[id*="firstname" i], input[placeholder*="Firstname" i]');
          var othernameInput = document.querySelector('input[name*="othername" i], input[id*="othername" i], input[placeholder*="Othername" i]');

          if (surnameInput && firstnameInput && surnameInput.value && firstnameInput.value) {
            fullName = (surnameInput.value.trim() + ' ' + firstnameInput.value.trim() + (othernameInput && othernameInput.value ? ' ' + othernameInput.value.trim() : '')).trim();
          }

          // Check navbar format: e.g. "IKEBUWA Praise Ifechukwude (25/SCI01/057)"
          if (!fullName) {
            var navMatch = text.match(/([A-Z][a-zA-Z\\s]{3,45})\\s*\\((\\d{2}\\/[A-Za-z0-9]{2,8}\\/\\d{2,5})\\)/);
            if (navMatch) {
              fullName = navMatch[1].replace(/welcome|student|portal|logged in as/gi, '').trim();
              if (!matricNumber) matricNumber = navMatch[2].toUpperCase();
            }
          }

          // Fallback to profile elements
          if (!fullName) {
            var nameEl = document.querySelector('.user-name, .profile-name, #lblStudentName, .navbar-text, .username, .profile-info h4, span[id*="Name" i], .user-panel .info p, .student-name');
            if (nameEl && nameEl.innerText && nameEl.innerText.trim().length > 3) {
              fullName = nameEl.innerText.replace(/welcome|student|logged in as|portal/gi, '').trim();
            }
          }

          if (!fullName) {
            var nameMatch = text.match(/(?:Student Name|Full Name|Name)\\s*[:\\-]\\s*([A-Za-z\\s]{3,40})(?:\\n|\\r|\$)/i);
            if (nameMatch) {
              fullName = nameMatch[1].trim();
            }
          }

          // 3. Department & Level from "Computer Science (200 Level)" format
          var deptLevelMatch = text.match(/([A-Za-z\\s&/]{3,45})\\s*\\(([1-6]00\\s*Level)\\)/i);
          var department = null;
          var level = null;
          if (deptLevelMatch) {
            department = deptLevelMatch[1].trim();
            level = deptLevelMatch[2].trim();
          }

          if (!department) {
            var deptEl = document.querySelector('span[id*="Department" i], span[id*="Dept" i]');
            department = deptEl && deptEl.innerText.trim().length > 2 ? deptEl.innerText.trim() : null;
          }
          if (!department) {
            var deptMatch = text.match(/(?:Department of|Department|Programme)\\s*[:\\-]?\\s*([A-Za-z\\s&/]{4,50})(?:\\n|\\r|,|\$)/i);
            if (deptMatch) department = deptMatch[1].trim();
          }

          // 4. College
          var colEl = document.querySelector('span[id*="College" i]');
          var college = colEl && colEl.innerText.trim().length > 2 ? colEl.innerText.trim() : null;
          if (!college) {
            var colMatch = text.match(/(?:College of|College|Faculty)\\s*[:\\-]?\\s*([A-Za-z\\s&]{4,50})(?:\\n|\\r|,|\$)/i);
            if (colMatch) college = colMatch[1].trim();
          }

          // 5. Academic Level fallback (100L - 600L)
          if (!level) {
            var lvlMatch = text.match(/\\b([1-6]00)\\s*(?:Level|L)?\\b/i);
            level = lvlMatch ? lvlMatch[1] + 'L' : null;
          }

          // 6. Validation Code (e.g. "Validation Code: 17552282")
          var valMatch = text.match(/(?:Validation Code|Validation)\\s*[:\\-]?\\s*(\\d{6,12})/i);
          var validationCode = valMatch ? valMatch[1].trim() : null;

          // 7. Photo URL from Temporary ID card or Profile Image
          var photoUrl = null;
          var imgEl = document.querySelector('.id-card img, #imgStudent, img[src*="passport" i], img[src*="student" i], img[src*="photo" i], table img[src*="upload" i]');
          if (imgEl && imgEl.src && imgEl.src.startsWith('http')) {
            photoUrl = imgEl.src;
          }

          // 8. Blood Group & Religion
          var bgMatch = text.match(/\\b(A|B|AB|O)[+-]\\b/);
          var bloodGroup = bgMatch ? bgMatch[0] : null;

          // 9. Academic Session (e.g. 2024/2025, 2025/2026)
          var sessMatch = text.match(/\\b(20\\d{2}\\/20\\d{2})\\b/);
          var session = sessMatch ? sessMatch[1] : null;

          // 10. CGPA & GPA (from my-dashboard or Results)
          var cgpaMatch = text.match(/(?:CGPA|Cumulative GPA|Cumulative Grade Point Average|C\\.G\\.P\\.A)\\s*[:\\-]?\\s*([0-5]\\.\\d{1,2})/i);
          var cgpa = cgpaMatch ? parseFloat(cgpaMatch[1]) : null;

          var gpaMatch = text.match(/(?:GPA|Current GPA|Grade Point Average|G\\.P\\.A)\\s*[:\\-]?\\s*([0-5]\\.\\d{1,2})/i);
          var gpa = gpaMatch ? parseFloat(gpaMatch[1]) : null;

          // 11. Registered Courses from tables
          var courses = [];
          var rows = document.querySelectorAll('tr');
          rows.forEach(function(row) {
            var rowText = row.innerText;
            var codeMatch = rowText.match(/\\b([A-Z]{3}\\s*\\d{3})\\b/);
            if (codeMatch) {
              var code = codeMatch[1].replace(/\\s+/, ' ');
              var cells = row.querySelectorAll('td, th');
              var title = '';
              var units = 3;
              var grade = 'A';

              cells.forEach(function(cell) {
                var cellTxt = cell.innerText.trim();
                if (cellTxt.length > 5 && !cellTxt.match(/^[A-Z]{3}\\s*\\d{3}\$/) && !title) {
                  title = cellTxt;
                }
                if (cellTxt.match(/^[1-6]\$/)) {
                  units = parseInt(cellTxt, 10);
                }
                if (cellTxt.match(/^[A-F]\$/i)) {
                  grade = cellTxt.toUpperCase();
                }
              });

              if (!courses.some(function(c) { return c.code === code; })) {
                courses.push({
                  code: code,
                  title: title || code,
                  units: units,
                  grade: grade,
                  day: 'Monday',
                  time: '08:00 - 10:00',
                  venue: 'Lecture Theatre'
                });
              }
            }
          });

          // Post extracted payload to Flutter Bridge
          if (matricNumber || fullName || courses.length > 0 || department || validationCode || cgpa) {
            AbuadPortalBridge.postMessage(JSON.stringify({
              type: 'PORTAL_DATA_SYNC',
              payload: {
                fullName: fullName,
                matricNumber: matricNumber,
                department: department,
                college: college,
                level: level,
                validationCode: validationCode,
                photoUrl: photoUrl,
                bloodGroup: bloodGroup,
                session: session,
                cgpa: cgpa,
                gpa: gpa,
                courses: courses,
                isManual: $manual
              }
            }));
          } else if ($manual) {
            AbuadPortalBridge.postMessage(JSON.stringify({
              type: 'PORTAL_DATA_SYNC',
              payload: { isEmpty: true, isManual: true }
            }));
          }
        } catch(e) {
          console.error('Portal Data Scraper Error:', e);
        }
      })();
    ''';

    try {
      await _controller?.runJavaScript(script);
    } catch (e) {
      debugPrint('Error running portal extraction script: $e');
    }
  }

  void _triggerManualExtraction() async {
    setState(() => _isExtracting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondaryTeal),
            ),
            SizedBox(width: 12),
            Text('Academic Algorithm: Scanning portal records...'),
          ],
        ),
        duration: Duration(milliseconds: 1400),
        backgroundColor: Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _injectPortalDataExtractor(manual: true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _isExtracting = false);
  }

  void _handleExtractedPortalData(Map<String, dynamic> payload) async {
    if (payload['isEmpty'] == true) {
      if (mounted && payload['isManual'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No student records or course tables detected on this portal page yet.'),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final matric = payload['matricNumber']?.toString().trim() ?? '';
    final name = payload['fullName']?.toString().trim() ?? '';
    final dept = payload['department']?.toString().trim() ?? '';
    final courses = payload['courses'] as List<dynamic>? ?? [];
    final valCode = payload['validationCode']?.toString().trim() ?? '';
    final photo = payload['photoUrl']?.toString().trim() ?? '';
    final cgpa = (payload['cgpa'] as num?)?.toDouble();
    final gpa = (payload['gpa'] as num?)?.toDouble() ?? cgpa;

    if (matric.isEmpty && name.isEmpty && dept.isEmpty && courses.isEmpty && valCode.isEmpty && cgpa == null) {
      return;
    }

    // SILENT BACKGROUND ALGORITHM:
    // Feed data directly into AcademicRepository (which powers Student ID Card and CGPA Simulator)
    // without showing nervous popups in the student's face.
    try {
      final repo = ref.read(academicRepositoryProvider);
      final coursesList = courses.map((c) => Map<String, dynamic>.from(c as Map)).toList();

      await repo.syncFromPortalData(
        fullName: name.isNotEmpty ? name : null,
        matricNumber: matric.isNotEmpty ? matric : null,
        department: dept.isNotEmpty ? dept : null,
        college: payload['college']?.toString(),
        level: payload['level']?.toString(),
        validationCode: valCode.isNotEmpty ? valCode : null,
        photoUrl: photo.isNotEmpty ? photo : null,
        bloodGroup: payload['bloodGroup']?.toString(),
        session: payload['session']?.toString(),
        cgpa: cgpa,
        gpa: gpa,
        courses: coursesList.isNotEmpty ? coursesList : null,
      );
    } catch (e) {
      debugPrint('Silent sync error: $e');
    }

    if (mounted) {
      setState(() {
        _detectedPortalData = payload;
      });

      // Discreet notification only if user clicked the scan button manually
      final isManual = payload['isManual'] == true;
      if (isManual) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.secondaryTeal, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Academic Algorithm: Synced student identity ($matric) to ID & Simulator',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showExtractedDataSyncDialog(Map<String, dynamic> data) {
    if (!mounted) return;

    final name = data['fullName']?.toString() ?? 'ABUAD Student';
    final matric = data['matricNumber']?.toString() ?? 'Pending Portal Sync';
    final dept = data['department']?.toString() ?? 'Not Specified';
    final college = data['college']?.toString() ?? 'College of Engineering';
    final level = data['level']?.toString() ?? '300L';
    final courses = (data['courses'] as List<dynamic>?) ?? [];
    final gpa = (data['gpa'] as num?)?.toDouble();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.secondaryTeal.withValues(alpha: 0.4))),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondaryTeal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_rounded, color: AppColors.secondaryTeal, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sync Official Portal Data', style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('Update ID, Timetable & Academics', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The following verified records were extracted from the ABUAD e-Portal:',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 14),

              // Student Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreviewRow(Icons.person_rounded, 'Student Name', name),
                    const Divider(color: Colors.white10, height: 16),
                    _buildPreviewRow(Icons.badge_rounded, 'Matric No.', matric),
                    const Divider(color: Colors.white10, height: 16),
                    _buildPreviewRow(Icons.apartment_rounded, 'Department', dept),
                    const Divider(color: Colors.white10, height: 16),
                    _buildPreviewRow(Icons.account_balance_rounded, 'College', college),
                    const Divider(color: Colors.white10, height: 16),
                    _buildPreviewRow(Icons.grade_rounded, 'Level', level),
                    if (gpa != null) ...[
                      const Divider(color: Colors.white10, height: 16),
                      _buildPreviewRow(Icons.trending_up_rounded, 'GPA / Results', gpa.toStringAsFixed(2)),
                    ],
                  ],
                ),
              ),

              if (courses.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.secondaryTeal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book_rounded, color: AppColors.secondaryTeal, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${courses.length} registered course${courses.length == 1 ? '' : 's'} found! Auto-adds to your schedule.',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(academicRepositoryProvider);
              final result = await repo.syncFromPortalData(
                fullName: data['fullName']?.toString(),
                matricNumber: data['matricNumber']?.toString(),
                department: data['department']?.toString(),
                college: data['college']?.toString(),
                level: data['level']?.toString(),
                bloodGroup: data['bloodGroup']?.toString(),
                session: data['session']?.toString(),
                gpa: gpa,
                courses: courses.map((c) => Map<String, dynamic>.from(c as Map)).toList(),
              );

              if (mounted) {
                setState(() => _detectedPortalData = null);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Academic profile updated! (${result['importedCoursesCount']} courses added to timetable)',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF0F172A),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            child: const Text('Sync to ABUAD App', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.secondaryTeal),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
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
                  activeThumbColor: AppColors.secondaryTeal,
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

  void _navigateToUrl(String url) async {
    setState(() => _currentUrl = url);
    if (kIsWeb || _controller == null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      _controller?.loadRequest(Uri.parse(url));
    }
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
            icon: _isExtracting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondaryTeal),
                  )
                : const Icon(Icons.sync_rounded, color: AppColors.secondaryTeal),
            tooltip: 'Sync Portal Records to App',
            onPressed: _isExtracting ? null : _triggerManualExtraction,
          ),
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
            tooltip: kIsWeb ? 'Refresh Saved Credentials' : 'Reload Page',
            onPressed: () {
              if (kIsWeb || _controller == null) {
                _loadStoredCredentials();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshed vaulted credentials!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              } else {
                _hasAttemptedAutoFill = false;
                _controller?.reload();
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1E293B),
            onSelected: (val) async {
              switch (val) {
                case 'sync':
                  _triggerManualExtraction();
                  break;
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
                value: 'sync',
                child: Row(
                  children: [
                    Icon(Icons.sync_rounded, color: AppColors.secondaryTeal, size: 18),
                    SizedBox(width: 10),
                    Text('Sync Portal Records', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
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

          // Browser View or Web Portal Hub
          Expanded(
            child: (kIsWeb || _controller == null)
                ? _buildWebPortalHub()
                : WebViewWidget(controller: _controller!),
          ),

          // Live Detected Portal Records Banner
          if (_detectedPortalData != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E293B),
                    Color(0xFF0D3B3F),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondaryTeal.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_rounded, color: AppColors.secondaryTeal, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ABUAD Portal Profile Detected',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        Text(
                          '${_detectedPortalData!['matricNumber'] ?? _detectedPortalData!['fullName'] ?? 'Student Profile'} • Tap to Sync',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showExtractedDataSyncDialog(_detectedPortalData!),
                    child: const Text('Sync App', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _detectedPortalData = null),
                  ),
                ],
              ),
            ),

          // Browser Navigation Bottom Bar
          if (!kIsWeb)
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
                        onPressed: _canGoBack ? () => _controller?.goBack() : null,
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: _canGoForward ? Colors.white : Colors.white24),
                        onPressed: _canGoForward ? () => _controller?.goForward() : null,
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
            color: isSelected ? Colors.white : Colors.white,
          ),
        ),
        backgroundColor: isSelected ? AppColors.secondaryTeal : const Color(0xFF1E293B),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onPressed: () => _navigateToUrl(url),
      ),
    );
  }

  Widget _buildWebPortalHub() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Banner
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0D2538),
                      Color(0xFF0F172A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.secondaryTeal.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.secondaryTeal.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.school_rounded, color: AppColors.secondaryTeal, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Afe Babalola University',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Official Integrated e-Portal',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LIVE',
                                style: GoogleFonts.inter(
                                  color: Colors.greenAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Direct link to portal.abuad.edu.ng. For security and cookie isolation, web browsers require the university portal to open in its dedicated tab. Use your vaulted credentials below for instant 1-tap copy.',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Launch Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                          shadowColor: AppColors.secondaryTeal.withValues(alpha: 0.5),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        label: Text(
                          'Open e-Portal in New Tab',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          final uri = Uri.parse(_currentUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Vaulted Credentials Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.vpn_key_rounded, color: Colors.amberAccent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Vaulted Portal Credentials',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _openCredentialVaultSheet,
                          icon: const Icon(Icons.edit_rounded, size: 14, color: AppColors.secondaryTeal),
                          label: Text(
                            _savedUsername.isNotEmpty ? 'Edit' : 'Save',
                            style: GoogleFonts.inter(
                              color: AppColors.secondaryTeal,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Matric Number Tile
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, color: Colors.white54, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Matric / Username',
                                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 10.5, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _savedUsername.isNotEmpty ? _savedUsername : 'Not set (tap Edit to save)',
                                  style: GoogleFonts.inter(
                                    color: _savedUsername.isNotEmpty ? Colors.white : Colors.white38,
                                    fontSize: 14,
                                    fontWeight: _savedUsername.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_savedUsername.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: AppColors.secondaryTeal, size: 18),
                              tooltip: 'Copy Matric Number',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _savedUsername));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Matric number copied to clipboard!'),
                                    duration: Duration(milliseconds: 1500),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Password Tile
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Portal Password',
                                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 10.5, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _savedPassword.isNotEmpty
                                      ? (_obscureWebPassword ? '••••••••••••' : _savedPassword)
                                      : 'Not set (tap Edit to save)',
                                  style: GoogleFonts.inter(
                                    color: _savedPassword.isNotEmpty ? Colors.white : Colors.white38,
                                    fontSize: 14,
                                    fontWeight: _savedPassword.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                    letterSpacing: _savedPassword.isNotEmpty && _obscureWebPassword ? 2 : 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_savedPassword.isNotEmpty) ...[
                            IconButton(
                              icon: Icon(
                                _obscureWebPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.white54,
                                size: 18,
                              ),
                              tooltip: _obscureWebPassword ? 'Show password' : 'Hide password',
                              onPressed: () {
                                setState(() => _obscureWebPassword = !_obscureWebPassword);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: AppColors.secondaryTeal, size: 18),
                              tooltip: 'Copy Password',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _savedPassword));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password copied to clipboard!'),
                                    duration: Duration(milliseconds: 1500),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded, color: Colors.amberAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tip: 1-tap copy your credentials, then paste directly into portal.abuad.edu.ng',
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick University Portals Strip
              Text(
                'Direct Portals & Resources',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildWebPortalLinkCard(
                title: 'Official e-Portal Home',
                subtitle: 'Course registration, fees, biodata & exam passes',
                url: 'https://portal.abuad.edu.ng/PortalHome',
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF0284C7),
              ),
              const SizedBox(height: 10),
              _buildWebPortalLinkCard(
                title: 'Academic Transcripts Portal',
                subtitle: 'Official degree verification & student transcripts',
                url: 'https://portal.abuad.edu.ng/Transcript',
                icon: Icons.description_outlined,
                color: Colors.purpleAccent,
              ),
              const SizedBox(height: 10),
              _buildWebPortalLinkCard(
                title: 'University Calendar & Timetable',
                subtitle: 'Academic schedules, resumptions & convocation',
                url: 'https://portal.abuad.edu.ng/Calendar',
                icon: Icons.event_note_rounded,
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 10),
              _buildWebPortalLinkCard(
                title: 'Lecturers & Staff Directory',
                subtitle: 'Faculty contact details and office directory',
                url: 'https://portal.abuad.edu.ng/Lecturers',
                icon: Icons.people_alt_rounded,
                color: Colors.amberAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebPortalLinkCard({
    required String title,
    required String subtitle,
    required String url,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      onTap: () => _navigateToUrl(url),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
          ],
        ),
      ),
    );
  }
}
