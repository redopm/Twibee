import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/settings_group.dart';
import '../services/settings_service.dart';
import '../services/push_notification_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  SupabaseClient get _supabase => Supabase.instance.client;
  bool _isLoading = false;
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  // ── Multiple Account Support ──
  void _showMultiAccountSheet() {
    final user = _supabase.auth.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text('Accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                // Current account tile
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.orange,
                    child: Icon(Icons.person, color: AppColors.white),
                  ),
                  title: Text(user?.phone ?? 'Current account'),
                  subtitle: const Text('Active'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.orange, width: 2),
                    ),
                    child: const Icon(Icons.add, color: AppColors.orange),
                  ),
                  title: const Text('Add account', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Sign in with another phone number'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Log out first, then sign in with a new number to add another account')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Two-Step Verification (TOTP via Supabase MFA) ──
  Future<void> _setupTwoStep() async {
    setState(() => _isLoading = true);
    try {
      // Check if TOTP is already enrolled
      final factors = await _supabase.auth.mfa.listFactors();
      final existingTotp = factors.totp.isNotEmpty ? factors.totp.first : null;

      if (existingTotp != null && existingTotp.status == FactorStatus.verified) {
        // Already enrolled — offer to disable
        if (!mounted) return;
        final disable = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Two-step verification'),
            content: const Text('Two-step verification is already active. Do you want to disable it?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Disable', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (disable == true) {
          await _supabase.auth.mfa.unenroll(existingTotp.id);
          _showSuccess('Two-step verification disabled.');
        }
        setState(() => _isLoading = false);
        return;
      }

      // Enroll new TOTP factor
      final response = await _supabase.auth.mfa.enroll(factorType: FactorType.totp);
      final uri = response.totp?.qrCode ?? '';
      final secret = response.totp?.secret ?? '';
      final factorId = response.id;

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      _showTotpQrSheet(factorId, secret, uri);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Two-step setup failed: $e');
    }
  }

  void _showTotpQrSheet(String factorId, String secret, String qrUri) {
    final codeController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text('Set up Two-Step Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Scan this QR code with your authenticator app (Google Authenticator, Authy, etc.)',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                // TOTP QR Code
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16)],
                  ),
                  child: qrUri.isNotEmpty
                      ? QrImageView(
                          data: qrUri,
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: AppColors.white,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: AppColors.orange),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: AppColors.dark),
                        )
                      : const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                ),
                const SizedBox(height: 16),
                // Manual secret entry option
                if (secret.isNotEmpty) ...[
                  const Text('Or enter this code manually:', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: secret));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Secret key copied!')));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(secret, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 2)),
                          const SizedBox(width: 8),
                          const Icon(Icons.copy, size: 16, color: AppColors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // Verify OTP
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    labelText: 'Enter 6-digit code from app',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final code = codeController.text.trim();
                      if (code.length != 6) return;
                      try {
                        // Create challenge then verify it
                        final challenge = await _supabase.auth.mfa.challenge(factorId: factorId);
                        await _supabase.auth.mfa.verify(
                          factorId: factorId,
                          challengeId: challenge.id,
                          code: code,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        _showSuccess('Two-step verification enabled successfully!');
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Invalid code: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Verify & Enable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Security Notifications ──
  void _showSecurityNotifications(SettingsService settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 20),
                    const Text('Security Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Get alerted when your security settings change.',
                        style: TextStyle(color: AppColors.grey, fontSize: 13)),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('New login alerts'),
                      subtitle: const Text('Notify me when a new device logs in'),
                      value: settings.getSetting('sec_notify_login', defaultValue: true),
                      activeColor: AppColors.orange,
                      onChanged: (v) {
                        settings.updateSetting('sec_notify_login', v);
                        setModalState(() {});
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Password changes'),
                      subtitle: const Text('Notify me when my password is changed'),
                      value: settings.getSetting('sec_notify_password', defaultValue: true),
                      activeColor: AppColors.orange,
                      onChanged: (v) {
                        settings.updateSetting('sec_notify_password', v);
                        setModalState(() {});
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Two-step changes'),
                      subtitle: const Text('Notify me when 2FA is enabled or disabled'),
                      value: settings.getSetting('sec_notify_2fa', defaultValue: true),
                      activeColor: AppColors.orange,
                      onChanged: (v) {
                        settings.updateSetting('sec_notify_2fa', v);
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── Request Account Info ──
  Future<void> _requestAccountInfo() async {
    try {
      _showSuccess('Generating report...');
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final profileData = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();

      final report = {
        'generated_at': DateTime.now().toIso8601String(),
        'user': {
          'id': user.id,
          'phone': user.phone,
          'email': user.email,
          'created_at': user.createdAt,
          'last_sign_in': user.lastSignInAt,
        },
        'profile': profileData,
      };

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/account_info.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(report));

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'My Twibee Account Info',
        );
      }
    } catch (e) {
      _showError('Failed to generate report: $e');
    }
  }

  // ── Delete Account ──
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Are you sure? This will permanently delete ALL your messages, profile data, and settings. This action CANNOT be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Forever', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await PushNotificationService().unregisterDeviceToken();
        await _supabase.functions.invoke('delete_account');
        await _supabase.auth.signOut();
      } catch (e) {
        _showError('Failed to delete account: $e');
      }
    }
  }

  // ── Change Phone ──
  Future<void> _changePhoneNumber() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change phone number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your new phone number. We will send an OTP to verify it.',
                style: TextStyle(color: AppColors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: '+91 9876543210', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send OTP', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _supabase.auth.updateUser(UserAttributes(phone: result));
        _showSuccess('OTP sent to $result — please verify on next screen.');
      } catch (e) {
        _showError('Failed to change phone: $e');
      }
    }
  }

  // ── Update Email ──
  Future<void> _updateEmail() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('A confirmation link will be sent to verify your new email.',
                style: TextStyle(color: AppColors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'yourname@email.com', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: AppColors.orange)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _supabase.auth.updateUser(UserAttributes(email: result));
        _showSuccess('Confirmation email sent to $result. Please check your inbox.');
      } catch (e) {
        _showError('Failed to update email: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Account'),
      body: Consumer<SettingsService>(
        builder: (context, settings, _) {
          // Check if 2FA is being set up
          return Stack(
            children: [
              ListView(
                children: [
                  // ── Current Account ──
                  SettingsGroup(
                    header: 'Accounts',
                    footer: 'You can add multiple accounts and switch between them.',
                    children: [
                      // Current account info tile
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF007AFF),
                          child: Text(
                            user?.phone?.isNotEmpty == true
                                ? (user!.phone!.length > 2 ? user.phone![user.phone!.length - 2] : '?')
                                : '?',
                            style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(user?.phone ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Active account', style: TextStyle(color: Colors.green)),
                        trailing: const Icon(Icons.check_circle, color: Colors.green),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 60.0),
                        child: Divider(height: 1, thickness: 0.5, color: AppColors.lightGrey),
                      ),
                      SettingsItem(
                        title: 'Add account',
                        icon: Icons.add,
                        iconBackgroundColor: AppColors.orange,
                        titleColor: AppColors.dark,
                        showDivider: false,
                        onTap: _showMultiAccountSheet,
                      ),
                    ],
                  ),

                  // ── Login & Security ──
                  SettingsGroup(
                    header: 'Login and security',
                    children: [
                      // Email address
                      SettingsItem(
                        title: 'Email address',
                        subtitle: user?.email ?? 'Not set',
                        icon: Icons.email_outlined,
                        iconBackgroundColor: AppColors.orange,
                        onTap: _updateEmail,
                      ),
                      SettingsItem(
                        title: 'Two-step verification',
                        subtitle: _isLoading ? 'Checking status...' : 'Add extra protection to your account',
                        icon: Icons.password,
                        iconBackgroundColor: AppColors.orange,
                        trailing: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                        onTap: _isLoading ? null : _setupTwoStep,
                      ),
                      SettingsItem(
                        title: 'Security notifications',
                        subtitle: settings.getSetting('sec_notify_login', defaultValue: true) ? 'On' : 'Off',
                        icon: Icons.security,
                        iconBackgroundColor: AppColors.orange,
                        showDivider: false,
                        onTap: () => _showSecurityNotifications(settings),
                      ),
                    ],
                  ),

                  // ── Your Account ──
                  SettingsGroup(
                    header: 'Your account',
                    children: [
                      SettingsItem(
                        title: 'Change phone number',
                        icon: Icons.phone_android,
                        iconBackgroundColor: AppColors.orange,
                        onTap: _changePhoneNumber,
                      ),
                      SettingsItem(
                        title: 'Request account info',
                        subtitle: 'Download a report of your account data',
                        icon: Icons.description_outlined,
                        iconBackgroundColor: AppColors.orange,
                        onTap: _requestAccountInfo,
                      ),
                      SettingsItem(
                        title: 'Ad preferences',
                        subtitle: 'Manage how your info is used for ads',
                        icon: Icons.ads_click,
                        iconBackgroundColor: AppColors.orange,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Ad Preferences'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Personalized ads in Status'),
                                    value: settings.getSetting('ad_pref_status', defaultValue: true),
                                    activeColor: AppColors.orange,
                                    onChanged: (v) => settings.updateSetting('ad_pref_status', v),
                                  ),
                                  SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Personalized ads in Channels'),
                                    value: settings.getSetting('ad_pref_channels', defaultValue: true),
                                    activeColor: AppColors.orange,
                                    onChanged: (v) => settings.updateSetting('ad_pref_channels', v),
                                  ),
                                ],
                              ),
                              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
                            ),
                          );
                        },
                      ),
                      SettingsItem(
                        title: 'Delete account',
                        icon: Icons.delete_outline,
                        isDestructive: true,
                        showDivider: false,
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                ],
              ),
              if (_isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}

