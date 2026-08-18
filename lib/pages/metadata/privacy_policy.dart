// pages/privacy_policy.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../fan_Funzy_design.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
        title: Text('Privacy Policy', style: FanTypography.headline),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last Updated
            Container(
              padding: const EdgeInsets.all(16),
              decoration: FanDecorations.card(isActive: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.update, color: FanColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Last Updated: February 14, 2026',
                        style: FanTypography.body.copyWith(
                          color: FanColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your privacy is important to us at Funzy. This Privacy Policy explains how we collect, use, and protect your personal information when you use our social media, fixture viewing, and voting platform.',
                    style: FanTypography.body.copyWith(
                      color: FanColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Navigation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: FanDecorations.card(isActive: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Navigation',
                    style: FanTypography.title.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildNavChip('Information We Collect', 1),
                      _buildNavChip('How We Use Your Data', 2),
                      _buildNavChip('Data Sharing', 3),
                      _buildNavChip('Your Rights', 4),
                      _buildNavChip('Data Security', 5),
                      _buildNavChip('Contact Us', 6),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 1: Information We Collect
            _buildSection(
              number: 1,
              title: 'Information We Collect',
              icon: Icons.info_outline,
              content: [
                '• **Account Information**: Username, phone number, and password when you register',
                '• **Profile Information**: Profile picture, bio, and preferences you choose to add',
                '• **Usage Data**: Your interactions with fixtures, votes, comments, and social features',
                '• **Device Information**: Device type, operating system, and app version',
                '• **Voting History**: All your fixture predictions and voting activity',
                '• **Social Interactions**: Comments, likes, shares, and connections with other users',
              ],
            ),

            const SizedBox(height: 20),

            // Section 2: How We Use Your Information
            _buildSection(
              number: 2,
              title: 'How We Use Your Information',
              icon: Icons.settings_applications,
              content: [
                '• To create and manage your account',
                '• To process your fixture votes and display results',
                '• To enable social features like comments and interactions',
                '• To send notifications about fixture updates and voting results',
                '• To improve our app and develop new features',
                '• To detect and prevent fraudulent activity',
                '• To provide customer support',
              ],
            ),

            const SizedBox(height: 20),

            // Section 3: Data Sharing
            _buildSection(
              number: 3,
              title: 'Data Sharing',
              icon: Icons.share,
              content: [
                '• **Public Information**: Your username, votes, and comments are visible to other users',
                '• **Service Providers**: We may share data with trusted third parties who help operate our app',
                '• **Legal Requirements**: We may disclose information if required by law',
                '• **Business Transfers**: In case of merger or acquisition, your data may be transferred',
              ],
            ),

            const SizedBox(height: 20),

            // Section 4: Your Rights
            _buildSection(
              number: 4,
              title: 'Your Rights',
              icon: Icons.gavel,
              content: [
                '• **Access**: Request a copy of your personal data',
                '• **Correction**: Update or correct your information',
                '• **Deletion**: Request account deletion',
                '• **Opt-out**: Disable non-essential data collection',
                '• **Export**: Download your data in a portable format',
              ],
            ),

            const SizedBox(height: 20),

            // Section 5: Data Security
            _buildSection(
              number: 5,
              title: 'Data Security',
              icon: Icons.security,
              content: [
                '• Encryption of sensitive data in transit and at rest',
                '• Regular security audits and updates',
                '• Secure authentication requirements',
                '• Limited employee access to user data',
                '• Immediate notification of any security breaches',
              ],
            ),

            const SizedBox(height: 20),

            // Section 6: Contact Us
            _buildSection(
              number: 6,
              title: 'Contact Us',
              icon: Icons.contact_mail,
              content: [
                'If you have questions about this Privacy Policy, please contact us:',
              ],
              isLast: true,
            ),

            const SizedBox(height: 16),

            // Contact Cards
            Container(
              padding: const EdgeInsets.all(20),
              decoration: FanDecorations.card(isActive: true),
              child: Column(
                children: [
                  _buildContactCard(
                    icon: Icons.email,
                    title: 'Email',
                    value: 'privacy@Funzypp.com',
                    onTap: () => _launchURL('mailto:privacy@Funzypp.com'),
                  ),
                  Divider(color: FanColors.border, height: 24),
                  _buildContactCard(
                    icon: Icons.web,
                    title: 'Website',
                    value: 'www.Funzypp.com/privacy',
                    onTap: () => _launchURL('https://www.Funzypp.com/privacy'),
                  ),
                  Divider(color: FanColors.border, height: 24),
                  _buildContactCard(
                    icon: Icons.location_on,
                    title: 'Address',
                    value: '123 App Street, Digital City, 12345',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Consent Statement
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FanColors.primaryDim,
                borderRadius: FanRadius.lgAll,
                border: Border.all(
                  color: FanColors.primaryMuted,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: FanColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'By using Funzy, you consent to our Privacy Policy and agree to its terms.',
                      style: FanTypography.body.copyWith(
                        color: FanColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildNavChip(String label, int section) {
    return GestureDetector(
      onTap: () {
        // Scroll to section functionality can be added here
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: FanColors.surfaceSunken,
          borderRadius: FanRadius.pillAll,
          border: Border.all(color: FanColors.primaryMuted),
        ),
        child: Text(
          label,
          style: FanTypography.caption.copyWith(
            color: FanColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required int number,
    required String title,
    required IconData icon,
    required List<String> content,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: FanDecorations.card(isActive: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: FanColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: FanTypography.body.copyWith(
                      color: FanColors.textInverse,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: FanColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: FanTypography.title.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...content.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                text,
                style: FanTypography.body.copyWith(
                  color: FanColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: FanRadius.lgAll,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: FanColors.primaryDim,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: FanColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: FanTypography.caption.copyWith(
                      color: FanColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: FanTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.open_in_new,
                color: FanColors.primary,
                size: 18,
              ),
          ],
        ),
      ),
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
