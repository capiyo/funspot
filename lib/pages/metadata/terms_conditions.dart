// pages/terms_conditions.dart
import 'package:flutter/material.dart';
import '../fan_Funzy_design.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

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
        title: Text('Terms & Conditions', style: FanTypography.headline),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Effective Date
            Container(
              padding: const EdgeInsets.all(16),
              decoration: FanDecorations.card(isActive: true),
              child: Row(
                children: [
                  Icon(Icons.event, color: FanColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Effective Date: February 14, 2026',
                    style: FanTypography.body.copyWith(
                      color: FanColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Welcome Message
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FanColors.primaryDim,
                borderRadius: FanRadius.lgAll,
                border: Border.all(
                  color: FanColors.primaryMuted,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.gavel, color: FanColors.primary, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome to Funzy',
                    style: FanTypography.headline.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please read these terms carefully before using our social media, fixture viewing, and voting platform.',
                    textAlign: TextAlign.center,
                    style: FanTypography.body.copyWith(
                      color: FanColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Terms Sections
            _buildTermSection(
              title: '1. Acceptance of Terms',
              icon: Icons.check_circle,
              content:
                  'By accessing or using Funzy, you agree to be bound by these Terms and Conditions. If you disagree with any part, you may not access the service. You must be at least 13 years old to use this app.',
            ),

            _buildTermSection(
              title: '2. User Accounts',
              icon: Icons.person,
              content:
                  'You are responsible for maintaining the confidentiality of your account credentials. You must notify us immediately of any unauthorized use. You are liable for all activities under your account.',
            ),

            _buildTermSection(
              title: '3. User Conduct',
              icon: Icons.rule,
              content:
                  'You agree not to:\n• Post offensive, harmful, or inappropriate content\n• Harass or bully other users\n• Impersonate others\n• Violate any laws\n• Spam or advertise without permission\n• Share false or misleading information',
            ),

            _buildTermSection(
              title: '4. Fixture Voting Rules',
              icon: Icons.how_to_vote,
              content:
                  '• One vote per fixture per user\n• Votes cannot be changed after submission\n• Manipulation of votes is prohibited\n• Results are final after fixture completion\n• Bonus credits are subject to fair use policy',
            ),

            _buildTermSection(
              title: '5. Social Features',
              icon: Icons.people,
              content:
                  'Your interactions on our platform must be respectful. We reserve the right to remove content that violates our guidelines. Users can block and report inappropriate behavior.',
            ),

            _buildTermSection(
              title: '6. Intellectual Property',
              icon: Icons.copyright,
              content:
                  'All content on Funzy, including logos, designs, and software, is owned by us. You retain rights to your posts but grant us license to display them. You may not copy or distribute app content without permission.',
            ),

            _buildTermSection(
              title: '7. Bonuses and Credits',
              icon: Icons.monetization_on,
              content:
                  '• Ksh 100 welcome bonus for new users\n• Bonuses have no cash value\n• Credits can only be used for predictions\n• We reserve the right to modify bonus terms\n• Fraudulent activity voids bonuses',
            ),

            _buildTermSection(
              title: '8. Termination',
              icon: Icons.cancel,
              content:
                  'We may terminate or suspend accounts for violations. You can delete your account anytime. Certain provisions survive termination.',
            ),

            _buildTermSection(
              title: '9. Limitation of Liability',
              icon: Icons.warning,
              content:
                  'Funzy is provided "as is" without warranties. We are not liable for indirect damages. Our liability is limited to the maximum extent permitted by law.',
            ),

            _buildTermSection(
              title: '10. Changes to Terms',
              icon: Icons.update,
              content:
                  'We may modify these terms. Continued use after changes constitutes acceptance. Material changes will be notified via app.',
              isLast: true,
            ),

            const SizedBox(height: 24),

            // Agreement Box
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FanColors.primaryDim,
                borderRadius: FanRadius.lgAll,
                border: Border.all(color: FanColors.primary),
              ),
              child: Column(
                children: [
                  Icon(Icons.handshake, color: FanColors.primary, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'By using Funzy, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
                    textAlign: TextAlign.center,
                    style: FanTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: FanDecorations.ghostButton,
                          child: Text(
                            'Decline',
                            style: FanTypography.button.copyWith(
                              color: FanColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: FanDecorations.primaryButton,
                          child: Text(
                            'Accept',
                            style: FanTypography.button.copyWith(
                              color: FanColors.textInverse,
                              fontWeight: FontWeight.w600,
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

  Widget _buildTermSection({
    required String title,
    required IconData icon,
    required String content,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      padding: const EdgeInsets.all(20),
      decoration: FanDecorations.card(isActive: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: FanColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: FanTypography.title.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: FanTypography.body.copyWith(
              color: FanColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
