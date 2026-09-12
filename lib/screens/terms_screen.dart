import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// D-149: reached from a link on [WelcomeScreen] (the very first screen) —
/// owner: "ensure that you have a terms and conditions link that indicates
/// that this is not medical advice ... if any of the copy is relatable to
/// what Green Pyramid does then copy it verbatim." The medical/professional-
/// advice disclaimer, AI-generated-content, and boilerplate legal sections
/// below are ported near-verbatim from goal-executor (Kansei)'s own
/// `terms_screen.dart`, since Green Pyramid makes the same kind of
/// AI-advisor-driven, non-professional guidance available (the Council of
/// Advisors) and carries the same subscription model (RevenueCat trials).
/// Sections specific to Kansei's own copy ("goal-setting", "Kansei") were
/// reworded for Green Pyramid's actual domain — a pyramid of life-value
/// categories, habits, and the Council.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const String effectiveDate = 'September 11, 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Terms and Conditions',
            style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Exo2')),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Effective date: $effectiveDate',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Exo2',
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 24),

              // ── Prominent disclaimer banner ──────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.brandGreen.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NOT MEDICAL OR PROFESSIONAL ADVICE',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Exo2',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppColors.brandGreen.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _body(
                      'Green Pyramid is a values-alignment and habit-tracking '
                      'application, including an AI-driven "Council of '
                      'Advisors" feature, intended solely for general '
                      'informational, organizational, and self-improvement '
                      'purposes. It does not provide medical, psychological, '
                      'psychiatric, therapeutic, mental-health, nutritional, '
                      'financial, legal, or other professional advice, '
                      'diagnosis, or treatment, and nothing in the app should '
                      'be interpreted as such.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              _section('1. Acceptance of These Terms'),
              _body(
                'These Terms and Conditions ("Terms") constitute a legally '
                'binding agreement between you ("you," "your," or "User") '
                'and the developer and operator of the Green Pyramid '
                'application ("we," "us," "our," or the "Company"). By '
                'downloading, installing, accessing, or using the Green '
                'Pyramid application and any related services (collectively, '
                'the "Service"), you acknowledge that you have read, '
                'understood, and agree to be bound by these Terms and by our '
                'Privacy Policy. If you do not agree to these Terms, you must '
                'not access or use the Service.',
              ),
              _body(
                'You represent that you are at least eighteen (18) years of '
                'age, or the age of legal majority in your jurisdiction, and '
                'that you have the legal capacity to enter into this '
                'agreement.',
              ),

              _section('2. No Medical, Psychological, or Professional Advice'),
              _body(
                'The Service, including all text, prompts, recommendations, '
                'AI-generated content, the Council of Advisors\' responses, '
                'category and habit suggestions, motivational material, and '
                'any other content made available through the app '
                '(collectively, "Content"), is provided for general '
                'informational and self-organization purposes only.',
              ),
              _body(
                'The Content is not a substitute for, and must not be relied '
                'upon in place of, the advice of a qualified physician, '
                'psychologist, psychiatrist, licensed therapist, counselor, '
                'dietitian, financial advisor, attorney, or other licensed or '
                'certified professional. Always seek the advice of a '
                'qualified professional with any questions you may have '
                'regarding a medical condition, mental-health concern, or any '
                'other matter requiring professional judgment.',
              ),
              _body(
                'Never disregard, avoid, or delay obtaining professional '
                'advice because of anything you have read or encountered in '
                'the Service. If you are experiencing a medical or '
                'mental-health emergency, or are having thoughts of '
                'self-harm, call your local emergency number or a crisis '
                'hotline immediately. We do not provide emergency services '
                'and the Service is not designed to detect, assess, or '
                'respond to crises of any kind.',
              ),
              _body(
                'No professional relationship of any kind — including but '
                'not limited to a doctor-patient, therapist-client, '
                'coaching, fiduciary, or advisory relationship — is created '
                'between you and the Company by your use of the Service, '
                'including by your use of the Council of Advisors.',
              ),

              _section('3. AI-Generated Content'),
              _body(
                'Certain Content, including every response from the Council '
                'of Advisors, is generated by automated systems, including '
                'large language models and other artificial-intelligence '
                'tools. Such Content may be inaccurate, incomplete, outdated, '
                'or inappropriate for your particular circumstances. We do '
                'not guarantee the accuracy, reliability, suitability, or '
                'completeness of any AI-generated Content, and you use it '
                'entirely at your own risk. You are solely responsible for '
                'evaluating, and for any decisions or actions taken on the '
                'basis of, any Content.',
              ),

              _section('4. Assumption of Risk and Personal Responsibility'),
              _body(
                'You are solely and exclusively responsible for your own '
                'values, goals, decisions, actions, conduct, health, safety, '
                'and well-being, and for any activities you undertake in '
                'connection with categories, habits, or tasks you set or '
                'track using the Service. Some habits you choose to pursue — '
                'including physical exercise, dietary changes, or other '
                'strenuous or potentially hazardous activities — carry '
                'inherent risks. You voluntarily assume all such risks. '
                'Before beginning any new exercise, diet, or wellness '
                'program, consult a qualified professional.',
              ),

              _section('5. Subscriptions, Billing, and Payment'),
              _body(
                'Certain features of the Service are offered on a paid '
                'subscription basis, including trials and subscriptions '
                'managed through RevenueCat. Subscriptions are billed '
                'through the applicable app store (such as the Apple App '
                'Store) in accordance with that store\'s terms. Subscriptions '
                'automatically renew unless cancelled at least twenty-four '
                '(24) hours before the end of the current billing period. '
                'You can manage and cancel subscriptions through your '
                'app-store account settings. Except where required by law, '
                'payments are non-refundable, and partial or unused periods '
                'are not refunded.',
              ),

              _section('6. License and Acceptable Use'),
              _body(
                'Subject to your compliance with these Terms, we grant you a '
                'limited, non-exclusive, non-transferable, revocable license '
                'to use the Service for your personal, non-commercial '
                'purposes. You agree not to misuse the Service, including by '
                'attempting to reverse-engineer, decompile, interfere with, '
                'or gain unauthorized access to any part of the Service, or '
                'by using it for any unlawful purpose.',
              ),

              _section('7. Intellectual Property'),
              _body(
                'The Service and all associated Content, design, trademarks, '
                'and software are owned by or licensed to the Company and '
                'are protected by applicable intellectual-property laws. '
                'These Terms do not grant you any ownership interest in the '
                'Service.',
              ),

              _section('8. Disclaimer of Warranties'),
              _body(
                'THE SERVICE AND ALL CONTENT ARE PROVIDED "AS IS" AND "AS '
                'AVAILABLE," WITHOUT WARRANTIES OF ANY KIND, WHETHER '
                'EXPRESS, IMPLIED, OR STATUTORY, INCLUDING WITHOUT '
                'LIMITATION THE IMPLIED WARRANTIES OF MERCHANTABILITY, '
                'FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND '
                'NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE SERVICE WILL BE '
                'UNINTERRUPTED, SECURE, ERROR-FREE, OR THAT ANY DEFECTS WILL '
                'BE CORRECTED, OR THAT THE SERVICE OR CONTENT WILL MEET YOUR '
                'REQUIREMENTS OR PRODUCE ANY PARTICULAR RESULT.',
              ),

              _section('9. Limitation of Liability'),
              _body(
                'TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO '
                'EVENT SHALL THE COMPANY OR ITS OFFICERS, DIRECTORS, '
                'EMPLOYEES, AGENTS, OR SUPPLIERS BE LIABLE FOR ANY INDIRECT, '
                'INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE '
                'DAMAGES, OR FOR ANY LOSS OF PROFITS, DATA, GOODWILL, OR '
                'OTHER INTANGIBLE LOSSES, ARISING OUT OF OR RELATING TO YOUR '
                'ACCESS TO OR USE OF, OR INABILITY TO ACCESS OR USE, THE '
                'SERVICE OR ANY CONTENT, WHETHER BASED ON WARRANTY, '
                'CONTRACT, TORT (INCLUDING NEGLIGENCE), OR ANY OTHER LEGAL '
                'THEORY, EVEN IF WE HAVE BEEN ADVISED OF THE POSSIBILITY OF '
                'SUCH DAMAGES.',
              ),
              _body(
                'TO THE MAXIMUM EXTENT PERMITTED BY LAW, OUR TOTAL AGGREGATE '
                'LIABILITY FOR ALL CLAIMS ARISING OUT OF OR RELATING TO THE '
                'SERVICE SHALL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU '
                'PAID US, IF ANY, FOR THE SERVICE IN THE TWELVE (12) MONTHS '
                'PRECEDING THE CLAIM, OR (B) FIFTY UNITED STATES DOLLARS '
                '(US \$50.00). SOME JURISDICTIONS DO NOT ALLOW CERTAIN '
                'LIMITATIONS, SO SOME OF THE ABOVE MAY NOT APPLY TO YOU.',
              ),

              _section('10. Indemnification'),
              _body(
                'You agree to indemnify, defend, and hold harmless the '
                'Company and its officers, directors, employees, and agents '
                'from and against any claims, liabilities, damages, losses, '
                'and expenses, including reasonable legal fees, arising out '
                'of or in any way connected with your use of the Service, '
                'your violation of these Terms, or your violation of any '
                'rights of any third party.',
              ),

              _section('11. Privacy'),
              _body(
                'Your use of the Service is also governed by our Privacy '
                'Policy, which describes how we collect, use, and safeguard '
                'your information. By using the Service, you consent to the '
                'practices described in the Privacy Policy.',
              ),

              _section('12. Modifications to the Service and Terms'),
              _body(
                'We reserve the right to modify, suspend, or discontinue the '
                'Service, or any part of it, at any time and without notice. '
                'We may also revise these Terms from time to time. Material '
                'changes will be indicated by updating the effective date '
                'above. Your continued use of the Service after changes '
                'become effective constitutes your acceptance of the revised '
                'Terms.',
              ),

              _section('13. Governing Law and Dispute Resolution'),
              _body(
                'These Terms are governed by and construed in accordance '
                'with the laws of the State of California, United States, '
                'without regard to its conflict-of-laws principles. Any '
                'dispute arising out of or relating to these Terms or the '
                'Service shall be subject to the exclusive jurisdiction of '
                'the state and federal courts located in California, and you '
                'consent to personal jurisdiction in those courts.',
              ),

              _section('14. Severability and Entire Agreement'),
              _body(
                'If any provision of these Terms is held to be invalid or '
                'unenforceable, that provision will be limited or eliminated '
                'to the minimum extent necessary, and the remaining '
                'provisions will remain in full force and effect. These '
                'Terms, together with the Privacy Policy, constitute the '
                'entire agreement between you and the Company regarding the '
                'Service and supersede all prior agreements.',
              ),

              _section('15. Contact'),
              _body(
                'If you have questions about these Terms, please contact us '
                'through the support channels listed on the application\'s '
                'app-store listing.',
              ),

              const SizedBox(height: 32),
              Center(
                child: Text(
                  'By using Green Pyramid, you acknowledge that you have '
                  'read and agree to these Terms and Conditions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Exo2',
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 12),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'Exo2',
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: AppColors.brandGreen,
          ),
        ),
      );

  Widget _body(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Exo2',
            color: AppColors.textSecondary.withValues(alpha: 0.9),
            height: 1.65,
          ),
        ),
      );
}
