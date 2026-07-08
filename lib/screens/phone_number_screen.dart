import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:country_picker/country_picker.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import 'otp_verification_screen.dart';

class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final TextEditingController _phoneController = TextEditingController();
  Country _selectedCountry = CountryParser.parseCountryCode('IN');
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formattedPhone = '+${_selectedCountry.phoneCode}$phone';
      await context.read<AuthService>().sendOtp(formattedPhone);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(phoneNumber: formattedPhone),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.orange,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white, size: 18),
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        title: const Text(
          'Enter Your Number',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phone Verification',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "We'll send a verification code to\nyour phone number.",
              style: TextStyle(
                fontSize: 16,
                color: AppColors.grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Input Row
            Row(
              children: [
                // Country Code
                GestureDetector(
                  onTap: () {
                    showCountryPicker(
                      context: context,
                      showPhoneCode: true,
                      favorite: ['IN', 'US', 'GB'],
                      countryListTheme: CountryListThemeData(
                        bottomSheetHeight: MediaQuery.of(context).size.height * 0.45,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      onSelect: (Country country) {
                        setState(() {
                          _selectedCountry = country;
                        });
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(_selectedCountry.flagEmoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          '+${_selectedCountry.phoneCode}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppColors.dark),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Phone Number Field
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      border: Border(
                        bottom: BorderSide(color: AppColors.border, width: 2),
                      ),
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 18,
                        letterSpacing: 1.2,
                        color: AppColors.dark,
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        hintText: '98765 43210',
                        hintStyle: TextStyle(
                          color: AppColors.dark.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Terms
            const Text(
              'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Send OTP Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: AppColors.white)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Send OTP',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: AppColors.white, size: 20),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

