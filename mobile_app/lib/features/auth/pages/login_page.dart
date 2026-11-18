import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';

/// Login screen — entry point for returning users.
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Welcome to TuklasRizal'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.place, size: 80, color: Color(0xFF033300)),
              const SizedBox(height: 24),
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF033300),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Discover culture, arts & tourism across Rizal',
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF6B6B6B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final auth = ref.read(authServiceProvider);
                    try {
                      await auth.signIn(emailCtrl.text, passwordCtrl.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Welcome back!'),
                            backgroundColor: Color(0xFF033300),
                          ),
                        );
                        context.go('/');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sign in failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Sign in'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.push('/signup'),
                child: const Text('Don\'t have an account? Sign up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signup screen — new user registration.
class SignupPage extends ConsumerWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Account'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
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
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final auth = ref.read(authServiceProvider);
                    try {
                      await auth.signUp(
                        emailCtrl.text,
                        passwordCtrl.text,
                        nameCtrl.text,
                      );
                      if (context.mounted) {
                        if (auth.emailConfirmationRequired) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Account created! Please check your email to confirm your address before signing in.',
                              ),
                              backgroundColor: Color(0xFFFFC800),
                            ),
                          );
                          context.pushReplacement('/login');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Account created! Select your tourism interests.',
                              ),
                              backgroundColor: Color(0xFF033300),
                            ),
                          );
                          context.pushReplacement('/onboarding/interests');
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Signup failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Create account'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
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
    final ref = this.ref;
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
                onPressed: _selected.isEmpty
                    ? null
                    : () async {
                        final auth = ref.read(authServiceProvider);
                        final profile = auth.currentUser;
                        if (profile != null && context.mounted) {
                          // Save selected tourism interests to Supabase (USER_INTERESTS).
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
