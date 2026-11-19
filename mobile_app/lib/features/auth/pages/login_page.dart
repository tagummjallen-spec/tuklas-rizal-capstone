import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/input_validation.dart';
import '../../../services/auth_service.dart';

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;
  const _GoogleButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                'G',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4285F4),
                ),
              ),
        label: const Text('Continue with Google'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1B1B1B),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDADCE0)),
        ),
      ),
    );
  }
}

/// Live checklist shown on the sign-up form; each met rule turns green.
class _PasswordChecklist extends StatelessWidget {
  final String password;

  const _PasswordChecklist({required this.password});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rule in passwordChecklist(password))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  rule.satisfied ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 14,
                  color: rule.satisfied
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF9E9E9E),
                ),
                const SizedBox(width: 6),
                Text(
                  rule.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: rule.satisfied
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF6B6B6B),
                    fontWeight: rule.satisfied
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Signup — email + password + name, then a 6-digit email OTP step.
class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  int _step = 0; // 0 = details, 1 = OTP verification
  bool _busy = false;
  bool _googleBusy = false;
  String? _error;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  Timer? _resendTimer;
  int _resendIn = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(_step == 0 ? 'Create Account' : 'Verify Your Email'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step == 0 ? _buildDetails() : _buildOtp(),
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.person_add, size: 80, color: Color(0xFF033300)),
        const SizedBox(height: 24),
        const Text(
          'Join TuklasRizal',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF033300),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Start discovering Rizal with us.',
          style: TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 32),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _nameCtrl,
          enabled: !_busy,
          onChanged: (value) {
            if (_nameError != null || value.isNotEmpty) {
              setState(() => _nameError = value.trim().isEmpty
                  ? 'Full name is required'
                  : null);
            }
          },
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: const Icon(Icons.person),
            errorText: _nameError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailCtrl,
          enabled: !_busy,
          onChanged: (value) {
            if (_emailError != null || value.isNotEmpty) {
              setState(() => _emailError = validateEmail(value));
            }
          },
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email),
            errorText: _emailError,
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordCtrl,
          enabled: !_busy,
          onChanged: (value) {
            if (_passwordError != null || value.isNotEmpty) {
              setState(() {
                _passwordError = validatePassword(value);
                if (_confirmCtrl.text.isNotEmpty) {
                  _confirmError = validateConfirmPassword(
                    value,
                    _confirmCtrl.text,
                  );
                }
              });
            }
          },
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock),
            errorText: _passwordError,
          ),
          obscureText: true,
        ),
        const SizedBox(height: 10),
        _PasswordChecklist(password: _passwordCtrl.text),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmCtrl,
          enabled: !_busy,
          onChanged: (value) {
            if (_confirmError != null || value.isNotEmpty) {
              setState(() => _confirmError = validateConfirmPassword(
                    _passwordCtrl.text,
                    value,
                  ));
            }
          },
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: const Icon(Icons.lock_outline),
            errorText: _confirmError,
          ),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _busy ? null : _submitDetails,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create account'),
          ),
        ),
        const SizedBox(height: 16),
        const _OrDivider(),
        const SizedBox(height: 16),
        _GoogleButton(busy: _googleBusy, onPressed: _googleSignUp),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.pushReplacement('/login'),
          child: const Text('Already have an account? Sign in'),
        ),
      ],
    );
  }

  Widget _buildOtp() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mark_email_read, size: 80, color: Color(0xFF033300)),
        const SizedBox(height: 24),
        const Text(
          'Enter your 6-digit code',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF033300),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a verification code to ${_emailCtrl.text.trim()}. '
          'Enter it below to activate your TuklasRizal profile.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 12,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '000000',
          ),
          onChanged: (value) {
            if (value.length == 6) _verifyOtp();
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _busy ? null : _verifyOtp,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verify & continue'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _resendIn > 0 || _busy ? null : _resendCode,
          child: Text(
            _resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend Code',
          ),
        ),
      ],
    );
  }

  Future<void> _submitDetails() async {
    if (_busy) return;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final name = _nameCtrl.text.trim();
    final nameError = name.isEmpty ? 'Full name is required' : null;
    final emailError = validateEmail(email);
    final passwordError = validatePassword(password);
    final confirmError = validateConfirmPassword(password, _confirmCtrl.text);

    setState(() {
      _error = null;
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmError = confirmError;
    });
    if (nameError != null ||
        emailError != null ||
        passwordError != null ||
        confirmError != null) {
      setState(() => _error = 'Please correct the highlighted fields.');
      return;
    }

    setState(() => _busy = true);
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signUp(email, password, name);

      if (!mounted) return;
      if (auth.emailConfirmationRequired) {
        setState(() => _busy = false);
        // Never let an unverified address continue into the app.
        await _showEmailConfirmationDialog(email);
        if (!mounted) return;
        setState(() {
          _step = 1;
          _busy = false;
        });
        _startResendCountdown();
      } else {
        // Email confirmation disabled: the session is already active.
        final profile = await auth.ensureProfile();
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Select your tourism interests.'),
            backgroundColor: Color(0xFF033300),
          ),
        );
        if (profile != null) context.pushReplacement('/onboarding/interests');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(e);
        _busy = false;
      });
    }
  }

  Future<void> _showEmailConfirmationDialog(String email) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Check your real inbox'),
        content: Text(
          'We sent a verification link/code to $email. Open it from a real, '
          'active mailbox to confirm your address. You cannot sign in until '
          'your email is verified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK, verify my email'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOtp() async {
    if (_busy) return;
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final auth = ref.read(authServiceProvider);
      await auth.verifySignupOtp(_emailCtrl.text.trim(), code);
      await auth.ensureProfile();
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified! Choose your tourism interests.'),
          backgroundColor: Color(0xFF033300),
        ),
      );
      context.pushReplacement('/onboarding/interests');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(e);
        _busy = false;
      });
    }
  }

  Future<void> _resendCode() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref.read(authServiceProvider).resendSignupOtp(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() => _busy = false);
      _startResendCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new 6-digit code is on its way.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(e);
        _busy = false;
      });
    }
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

  Future<void> _googleSignUp() async {
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
      // Ensures public.users is upserted from Google metadata and persists any
      // interests selected in the local 4-step welcome onboarding.
      final profile = await auth.completeGoogleSignIn(
        onboardingInterests: ref.read(onboardingControllerProvider).interests,
      );
      if (profile == null) return;
      final onboarded = await auth.hasSavedInterests(profile.id);
      if (!mounted) return;
      if (onboarded) {
        context.go('/');
      } else {
        context.pushReplacement('/onboarding/interests');
      }
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
        backgroundColor: isError ? const Color(0xFFB00020) : const Color(0xFF033300),
      ),
    );
  }
}

/// Return target for the Google OAuth redirect.
///
/// Supabase exchanges the authorization code for a session when the app opens
/// this route, then the profile is ensured and first-time users are sent to
/// interest onboarding.
class OAuthCallbackPage extends ConsumerStatefulWidget {
  const OAuthCallbackPage({super.key});

  @override
  ConsumerState<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends ConsumerState<OAuthCallbackPage> {
  String _status = 'Finishing Google sign-in…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
  }

  Future<void> _complete() async {
    final auth = ref.read(authServiceProvider);
    for (var attempt = 0; attempt < 6; attempt++) {
      final profile = await auth.completeGoogleSignIn(
        onboardingInterests: ref.read(onboardingControllerProvider).interests,
      );
      if (profile != null) {
        final onboarded = await auth.hasSavedInterests(profile.id);
        if (!mounted) return;
        if (onboarded) {
          context.go('/');
        } else {
          context.pushReplacement('/onboarding/interests');
        }
        return;
      }
      await Future.delayed(const Duration(milliseconds: 700));
    }
    if (!mounted) return;
    setState(() => _status = 'Could not complete Google sign-in. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signing in'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF033300)),
            const SizedBox(height: 16),
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tourism interest onboarding — USER_INTERESTS selection.
class InterestOnboardingPage extends ConsumerStatefulWidget {
  const InterestOnboardingPage({super.key});

  @override
  ConsumerState<InterestOnboardingPage> createState() => _InterestOnboardingPageState();
}

class _InterestOnboardingPageState extends ConsumerState<InterestOnboardingPage> {
  final Set<String> _selected = {};
  bool _submitting = false;

  final List<_Category> _categories = const [
    _Category(id: 'cultural', name: 'Cultural', description: 'Heritage sites and experiences', color: Color(0xFF033300)),
    _Category(id: 'festival', name: 'Festival', description: 'Town festivals and celebrations', color: Color(0xFFFFC800)),
    _Category(id: 'civic', name: 'Civic', description: 'Community activities', color: Color(0xFF033300)),
    _Category(id: 'sports', name: 'Sports', description: 'Sports events and activities', color: Color(0xFFFFC800)),
    _Category(id: 'health', name: 'Health', description: 'Health and wellness tourism', color: Color(0xFF033300)),
    _Category(id: 'food_heritage', name: 'Food/Heritage', description: 'Unique Rizal delicacies', color: Color(0xFFFFC800)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Interests'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.favorite, size: 64, color: Color(0xFFFFC800)),
                const SizedBox(height: 16),
                const Text(
                  'What interests you?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF033300),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select your tourism categories so TuklasRizal can personalize '
                  'your discovery feed and "Promote Towns and Events."',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF6B6B6B)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final c = _categories[i];
                final selected = _selected.contains(c.id);
                return CheckboxListTile(
                  title: Text(c.name),
                  subtitle: Text(c.description),
                  secondary: CircleAvatar(
                    backgroundColor: c.color.withValues(alpha: 0.15),
                    child: Icon(Icons.event, color: c.color, size: 20),
                  ),
                  value: selected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(c.id);
                      } else {
                        _selected.remove(c.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selected.isEmpty || _submitting
                    ? null
                    : () async {
                        if (_submitting) return;
                        setState(() => _submitting = true);
                        try {
                          final auth = ref.read(authServiceProvider);
                          final profile = await auth.ensureProfile() ?? auth.currentUser;
                          if (!context.mounted) return;
                          if (profile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not load your profile. Please sign in again.',
                                ),
                              ),
                            );
                            return;
                          }
                          await auth.setUserInterests(
                            profile.id,
                            _selected.toList(),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Interests saved!'),
                              backgroundColor: Color(0xFF033300),
                            ),
                          );
                          context.go('/');
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not save interests: ${friendlyAuthError(e)}',
                              ),
                            ),
                          );
                        } finally {
                          if (context.mounted) {
                            setState(() => _submitting = false);
                          }
                        }
                      },
                child: const Text('Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Category {
  final String id;
  final String name;
  final String description;
  final Color color;
  const _Category({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
  });
}
