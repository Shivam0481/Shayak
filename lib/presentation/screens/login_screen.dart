import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';
import '../widgets/shayak_input_field.dart';
import '../../data/repositories/auth_repository.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final UserRole expectedRole;
  
  const LoginScreen({super.key, required this.expectedRole});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      debugPrint('Logging in with ${_emailCtrl.text}');
      final user = await ref.read(authRepoProvider).login(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text.trim(),
          );
      debugPrint('Login result: ${user?.role}');
      if (user == null) {
        throw Exception('User record not found in database. Please register first.');
      }
      if (user.role != widget.expectedRole) {
        await ref.read(authRepoProvider).signOut();
        throw Exception('Access Denied: Account is not registered as ${widget.expectedRole.name}.');
      }
      // Success! The auth_gate will now show _MainShell. 
      // We must pop the login and role selection screens.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      debugPrint('Signing in with Google for role: ${widget.expectedRole}');
      final user = await ref.read(authRepoProvider).signInWithGoogle(targetRole: widget.expectedRole);
      debugPrint('Google Sign-In result: ${user?.role}');
      if (user == null) {
        // This could be because the user cancelled or some error occurred
        return; 
      }
      if (user.role != widget.expectedRole) {
        await ref.read(authRepoProvider).signOut();
        throw Exception('Access Denied: Google account is not registered as ${widget.expectedRole.name}.');
      }
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Hero Section
              Center(
                child: Column(
                  children: [
                    Text('${widget.expectedRole.name.toUpperCase()} LOGIN',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to your ${widget.expectedRole.name} account',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    ShayakInputField(
                      controller: _emailCtrl,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v == null || !v.contains('@') ? 'Enter valid email' : null,
                    ),
                    const SizedBox(height: 16),
                    ShayakInputField(
                      controller: _passwordCtrl,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) =>
                          v == null || v.length < 6 ? 'Min 6 characters' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.priorityRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.priorityRed)),
                      ),
                    ],
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Sign In',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        backgroundColor: Colors.white,
                      ),
                      icon: Image.network(
                        'https://developers.google.com/static/identity/images/g-logo.png',
                        height: 24,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_circle, color: Colors.blue),
                      ),
                      label: const Text('Sign In with Google',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                    ),
                    const SizedBox(height: 16),
                    if (widget.expectedRole != UserRole.admin)
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RegisterScreen(role: widget.expectedRole)),
                        ),
                        child: RichText(
                          text: const TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(color: Colors.grey),
                            children: [
                              TextSpan(
                                text: 'Register',
                                style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
