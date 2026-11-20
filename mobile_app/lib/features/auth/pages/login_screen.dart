import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/input_validation.dart';
import '../../../models/user_profile.dart';
import '../../../services/auth_service.dart';

/// Rizal Events Hub sign-in.
///
/// Full forest-green canvas with the yellow location-pin brand mark and a white
/// rounded card. Supports Google OAuth, passwordless 6-digit email OTP and the
/// existing email + password flow.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const Color _forest = Color(0xFF033300);
  static const Color _gold = Color(0xFFFFC800);
  static const Color _softGreen = Color(0xFFE8F0E5);

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _busy = false;
  bool _googleBusy = false;
  // Password is the primary/default email sign-in mode.
  bool _passwordMode = true;
  bool _otpSent = false;
  bool _navigated = false;
  String? _error;
  String? _emailError;
  String? _passwordError;
  Timer? _resendTimer;
  int _resendIn = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _forest,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Back',
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                ),
              ),
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                  color: _gold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on,
                    color: _forest, size: 40),
              ),
              const SizedBox(height: 14),
              const Text(
                'TUKLASRIZAL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Province of Rizal · Community Calendar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _otpSent ? _buildOtpStep() : _buildForm(),
              ),
              const SizedBox(height: 18),
              const Text(
                'Browsing as a guest? You can explore events and places '
                'without signing in.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Email / Google form
  // ---------------------------------------------------------------------------
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: _softGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mail_outline, color: _forest, size: 26),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Sign in to TuklasRizal',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _forest,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Save events, follow your towns and message the Tourism Coordinator.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 18),
        OutlinedButton(
          onPressed: _googleBusy ? null : _googleSignIn,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1B1B1B),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFDADCE0)),
            minimumSize: const Size.fromHeight(50),
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_googleBusy)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const _GoogleLogo(),
              const SizedBox(width: 10),
              const Text(
                'Continue with Google',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Or',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'EMAIL ADDRESS',
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B6B6B),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enabled: !_busy,
          onChanged: (value) {
            if (_emailError != null || value.isNotEmpty) {
              setState(() => _emailError = validateEmail(value));
            }
          },
          decoration: InputDecoration(
            hintText: 'name@gmail.com',
            prefixIcon: const Icon(Icons.alternate_email, size: 20),
            errorText: _emailError,
          ),
        ),
        if (_passwordMode) ...[
          const SizedBox(height: 14),
          const Text(
            'PASSWORD',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            enabled: !_busy,
            onChanged: (value) {
              if (_passwordError != null) {
                setState(() => _passwordError = null);
              }
            },
            decoration: InputDecoration(
              hintText: 'Your password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              errorText: _passwordError,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _busy ? null : (_passwordMode ? _signIn : _sendOtp),
            style: ElevatedButton.styleFrom(
              backgroundColor: _forest,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _passwordMode ? 'Sign In' : 'Send Sign-In Link / OTP',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 2),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _passwordMode = !_passwordMode;
                  _error = null;
                  _emailError = null;
                  _passwordError = null;
                }),
          child: Text(
            _passwordMode
                ? 'Use Sign-In Link / OTP instead'
                : 'Use Email & Password instead',
            style: const TextStyle(fontSize: 12.5, color: _forest),
          ),
        ),
        TextButton(
          onPressed: () => context.push('/signup'),
          child: const Text(
            'New here? Create an account',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF6B6B6B)),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 6-digit OTP step
  // ---------------------------------------------------------------------------
  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: _softGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_outlined,
                color: _forest, size: 26),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _forest,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the 6-digit code we sent to ${_emailCtrl.text.trim()}.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
            color: _forest,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '000000',
          ),
          onChanged: (value) {
            if (value.length == 6) _verifyOtp();
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _busy ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _forest,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Verify & Continue',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        TextButton(
          onPressed: _resendIn > 0 || _busy ? null : _resendOtp,
          child: Text(
            _resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend Code',
            style: const TextStyle(fontSize: 12.5, color: _forest),
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _otpSent = false;
            _otpCtrl.clear();
            _error = null;
          }),
          child: const Text(
            'Use a different email',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF6B6B6B)),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  Future<void> _sendOtp() async {
    if (_busy) return;
    final emailError = validateEmail(_emailCtrl.text);
    if (emailError != null) {
      setState(() => _emailError = emailError);
      return;
    }
    final email = _emailCtrl.text.trim();
    setState(() {
      _error = null;
      _emailError = null;
      _busy = true;
    });
    try {
      await ref.read(authServiceProvider).sendLoginOtp(email);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _busy = false;
      });
      _startResendCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(e);
        _busy = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    if (_busy) return;
    final emailError = validateEmail(_emailCtrl.text);
    if (emailError != null) {
      setState(() => _emailError = emailError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).sendLoginOtp(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() => _busy = false);
      _startResendCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(e);
        _busy = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_busy) return;
    final code = _otpCtrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final profile = await ref
          .read(authServiceProvider)
          .verifyLoginOtp(_emailCtrl.text.trim(), code);
      await _afterAuth(profile);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(e);
        _busy = false;
      });
    }
  }

  Future<void> _signIn() async {
    if (_busy) return;
    final emailError = validateEmail(_emailCtrl.text);
    final passwordError = _passwordCtrl.text.isEmpty
        ? 'Password is required'
        : null;
    if (emailError != null || passwordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
      });
      return;
    }
    setState(() {
      _error = null;
      _emailError = null;
      _passwordError = null;
      _busy = true;
    });
    try {
      final profile = await ref
          .read(authServiceProvider)
          .signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      await _afterAuth(profile);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(e);
        _busy = false;
      });
    }
  }

  Future<void> _googleSignIn() async {
    if (_busy || _googleBusy) return;
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      final launched = await auth.signInWithGoogle();
      if (!launched) {
        _showMessage(
          'Google sign-in could not start. Allow pop-ups and try again.',
          isError: true,
        );
        return;
      }
      // The deep-link / web-origin redirect resolves to a live session. Ensure
      // the profile exists and sync the 4-step welcome interests to Supabase.
      final profile = await auth.completeGoogleSignIn(
        onboardingInterests: ref.read(onboardingControllerProvider).interests,
      );
      if (profile != null) await _afterAuth(profile);
    } catch (e) {
      _showMessage(friendlyAuthMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFB00020) : _forest,
      ),
    );
  }

  Future<void> _afterAuth(UserProfile profile) async {
    if (!mounted || _navigated) return;
    _navigated = true;
    final auth = ref.read(authServiceProvider);
    var onboarded = true;
    try {
      onboarded = await auth.hasSavedInterests(profile.id);
    } catch (_) {
      // Assume a returning user if the lookup fails.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (onboarded) {
      context.go('/');
    }
    // First-time users are routed to onboarding by the app-level bootstrap.
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendIn -= 1;
        if (_resendIn <= 0) timer.cancel();
      });
    });
  }

}

/// Small four-colour "G" mark used on the Google button.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
