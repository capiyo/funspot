// pages/account_deletion.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../fan_Funzy_design.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  bool _isLoading = false;
  bool _confirmed = false;
  bool _understandsDataLoss = false;
  bool _understandsNoRefunds = false;
  String? _deletionStatus;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final String _deletionUrl =
      "https://clash-api-m5mr.onrender.com/api/user/delete";

  @override
  void dispose() {
    _reasonController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestAccountDeletion() async {
    if (!_confirmed || !_understandsDataLoss || !_understandsNoRefunds) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please confirm all checkboxes'),
          backgroundColor: FanColors.away,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: FanRadius.lgAll),
        ),
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password is required'),
          backgroundColor: FanColors.away,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: FanRadius.lgAll),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _deletionStatus = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('usertoken');
      final userData = prefs.getString('user');

      if (token == null || userData == null) {
        throw Exception('Not logged in');
      }

      final user = jsonDecode(userData);

      final response = await http.post(
        Uri.parse(_deletionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': user['id'],
          'password': _passwordController.text,
          'reason': _reasonController.text.isEmpty
              ? 'No reason provided'
              : _reasonController.text,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _deletionStatus = 'success';
        });

        // Clear local storage
        await prefs.clear();

        // Show success message
        _showSuccessDialog();
      } else {
        setState(() {
          _deletionStatus = 'error';
        });
        throw Exception(result['error'] ?? 'Deletion failed');
      }
    } catch (error) {
      setState(() {
        _deletionStatus = 'error';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: FanColors.away,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: FanRadius.lgAll),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: FanColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: FanRadius.xlAll,
            side: BorderSide(color: FanColors.border),
          ),
          title:  Icon(
            Icons.check_circle,
            color: FanColors.primary,
            size: 60,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Account Deletion Requested',
                style: FanTypography.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your account deletion request has been submitted. You will receive a confirmation email shortly. Your account will be permanently deleted within 30 days.',
                style: FanTypography.body.copyWith(
                  color: FanColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to previous page
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: FanDecorations.primaryButton,
                  child: Text(
                    'OK',
                    style: FanTypography.button.copyWith(
                      color: FanColors.textInverse,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FanColors.background,
      appBar: AppBar(
        backgroundColor: FanColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: FanColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Delete Account', style: FanTypography.headline),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FanColors.awayDim,
                borderRadius: FanRadius.lgAll,
                border:
                    Border.all(color: FanColors.away.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FanColors.awayDim,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: FanColors.away,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Warning: This action is permanent',
                          style: FanTypography.body.copyWith(
                            color: FanColors.away,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Once deleted, all your data will be permanently removed and cannot be recovered.',
                          style: FanTypography.caption.copyWith(
                            color: FanColors.away.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // What gets deleted
            Container(
              padding: const EdgeInsets.all(20),
              decoration: FanDecorations.card(isActive: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'When you delete your account:',
                    style: FanTypography.title.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _buildDeletionItem(
                    icon: Icons.person,
                    text: 'Profile information',
                    color: FanColors.away,
                  ),
                  _buildDeletionItem(
                    icon: Icons.how_to_vote,
                    text: 'All voting history and predictions',
                    color: FanColors.away,
                  ),
                  _buildDeletionItem(
                    icon: Icons.comment,
                    text: 'Comments and social interactions',
                    color: FanColors.away,
                  ),
                  _buildDeletionItem(
                    icon: Icons.emoji_events,
                    text: 'Points, badges, and achievements',
                    color: FanColors.away,
                  ),
                  _buildDeletionItem(
                    icon: Icons.attach_money,
                    text: 'Any unused credits or bonuses',
                    color: FanColors.draw,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // What remains
            Container(
              padding: const EdgeInsets.all(20),
              decoration: FanDecorations.card(isActive: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: FanColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Information that may remain:',
                        style: FanTypography.title.copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDeletionItem(
                    icon: Icons.receipt,
                    text: 'Anonymized transaction records (for legal purposes)',
                    color: FanColors.primary,
                  ),
                  _buildDeletionItem(
                    icon: Icons.chat,
                    text: 'Public comments may remain but will be anonymized',
                    color: FanColors.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Deletion Form
            Container(
              padding: const EdgeInsets.all(20),
              decoration: FanDecorations.card(isActive: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm Account Deletion',
                    style: FanTypography.title.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  // Password
                  Text(
                    'Enter your password to confirm',
                    style: FanTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    enabled: !_isLoading,
                    style: FanTypography.body.copyWith(
                      color: FanColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Your password',
                      hintStyle: FanTypography.body.copyWith(
                        color: FanColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: FanColors.surfaceSunken,
                      border: OutlineInputBorder(
                        borderRadius: FanRadius.lgAll,
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: FanRadius.lgAll,
                        borderSide: BorderSide(color: FanColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: FanRadius.lgAll,
                        borderSide: BorderSide(
                          color: FanColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Reason (optional)
                  Text(
                    'Reason for leaving (optional)',
                    style: FanTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _reasonController,
                    enabled: !_isLoading,
                    maxLines: 3,
                    style: FanTypography.body.copyWith(
                      color: FanColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tell us why you\'re leaving...',
                      hintStyle: FanTypography.body.copyWith(
                        color: FanColors.textTertiary,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      filled: true,
                      fillColor: FanColors.surfaceSunken,
                      border: OutlineInputBorder(
                        borderRadius: FanRadius.lgAll,
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: FanRadius.lgAll,
                        borderSide: BorderSide(color: FanColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: FanRadius.lgAll,
                        borderSide: BorderSide(
                          color: FanColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Confirmation Checkboxes
                  _buildCheckbox(
                    value: _confirmed,
                    onChanged: (value) =>
                        setState(() => _confirmed = value ?? false),
                    text:
                        'I confirm that I want to permanently delete my account',
                  ),
                  const SizedBox(height: 12),
                  _buildCheckbox(
                    value: _understandsDataLoss,
                    onChanged: (value) =>
                        setState(() => _understandsDataLoss = value ?? false),
                    text:
                        'I understand that all my data will be permanently lost',
                  ),
                  const SizedBox(height: 12),
                  _buildCheckbox(
                    value: _understandsNoRefunds,
                    onChanged: (value) =>
                        setState(() => _understandsNoRefunds = value ?? false),
                    text:
                        'I understand that I will not receive any refunds for unused credits',
                  ),

                  const SizedBox(height: 24),

                  // Delete Button
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _requestAccountDeletion,
                      child: Container(
                        height: 52,
                        decoration: _isLoading
                            ? BoxDecoration(
                                color: FanColors.surfaceSunken,
                                borderRadius: FanRadius.lgAll,
                                border: Border.all(color: FanColors.border),
                              )
                            : BoxDecoration(
                                color: FanColors.away,
                                borderRadius: FanRadius.lgAll,
                                boxShadow: FanShadows.button,
                              ),
                        child: _isLoading
                            ? Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: FanColors.textInverse,
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  'Permanently Delete Account',
                                  style: FanTypography.button.copyWith(
                                    color: FanColors.textInverse,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Alternative Contact
            Container(
              padding: const EdgeInsets.all(20),
              decoration: FanDecorations.card(isActive: true),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.headset_mic,
                        color: FanColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Need help?',
                              style: FanTypography.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Contact support for assistance',
                              style: FanTypography.caption.copyWith(
                                color: FanColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              _launchURL('mailto:support@Funzypp.com'),
                          child: Container(
                            height: 44,
                            decoration: FanDecorations.ghostButton,
                            child: Center(
                              child: Text(
                                'Email Support',
                                style: FanTypography.button.copyWith(
                                  color: FanColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              _launchURL('https://www.Funzypp.com/support'),
                          child: Container(
                            height: 44,
                            decoration: FanDecorations.ghostButton,
                            child: Center(
                              child: Text(
                                'Visit Help Center',
                                style: FanTypography.button.copyWith(
                                  color: FanColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildDeletionItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: FanTypography.body.copyWith(
                color: FanColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required Function(bool?) onChanged,
    required String text,
  }) {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: FanColors.away,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: FanTypography.body.copyWith(
              color: FanColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}
