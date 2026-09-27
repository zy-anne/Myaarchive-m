import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_palette.dart';

/// Password recovery flow, driven entirely by the optional security
/// question captured at sign-up (no email/SMS backend exists on mobile).
///
/// Step 1 — enter the account's username, look up its security question.
/// Step 2 — answer it and choose a new password.
///
/// If the account never set up a recovery question, there's no self-serve
/// path: the person is told plainly and pointed back to Sign In.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _usernameFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _answerController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isResetComplete = false;

  /// null while step 1 hasn't run yet; holds the fetched question once
  /// step 1 succeeds.
  String? _securityQuestion;

  @override
  void dispose() {
    _usernameController.dispose();
    _answerController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLookupQuestion() async {
    if (!_usernameFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final palette = context.palette;
    try {
      final question = await ref
          .read(authServiceProvider)
          .getSecurityQuestion(_usernameController.text.trim());

      if (!mounted) return;

      if (question == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "We couldn't find a recovery question for that account. "
              "If you never set one up at sign-up, there's no self-serve "
              "way to reset this password.",
            ),
            backgroundColor: palette.danger,
          ),
        );
        return;
      }

      setState(() => _securityQuestion = question);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: palette.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final palette = context.palette;
    try {
      await ref.read(authServiceProvider).resetPasswordWithSecurityAnswer(
            username: _usernameController.text.trim(),
            securityAnswer: _answerController.text,
            newPassword: _newPasswordController.text,
          );

      if (mounted) setState(() => _isResetComplete = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: palette.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Reset Password'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: palette.textMain),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: _isResetComplete
                ? _buildSuccessView(palette)
                : (_securityQuestion == null
                    ? _buildUsernameStep(palette)
                    : _buildResetStep(palette)),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameStep(AppPalette palette) {
    return Form(
      key: _usernameFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.help_outline_rounded, size: 44, color: palette.accent),
          const SizedBox(height: 16),
          Text(
            'Find Your Account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: palette.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter your username and we'll check whether you set up a "
            "recovery question at sign-up.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _usernameController,
            style: TextStyle(color: palette.textMain),
            decoration: InputDecoration(
              labelText: 'Username',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              filled: true,
              fillColor: palette.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: palette.border),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your username';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLookupQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Continue',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: Text(
                'Back to Sign In',
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep(AppPalette palette) {
    return Form(
      key: _resetFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_reset_rounded, size: 44, color: palette.accent),
          const SizedBox(height: 16),
          Text(
            'Answer & Reset',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: palette.textMain,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR SECURITY QUESTION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _securityQuestion!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.textMain,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _answerController,
            style: TextStyle(color: palette.textMain),
            decoration: InputDecoration(
              labelText: 'Your Answer',
              prefixIcon: const Icon(Icons.check_circle_outline_rounded),
              filled: true,
              fillColor: palette.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: palette.border),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please answer the question';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: palette.textMain),
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: palette.textSecondary,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              filled: true,
              fillColor: palette.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: palette.border),
              ),
            ),
            validator: (val) {
              if (val == null || val.length < 4) {
                return 'Password must be at least 4 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: palette.textMain),
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              filled: true,
              fillColor: palette.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: palette.border),
              ),
            ),
            validator: (val) {
              if (val != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleResetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Reset Password',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() => _securityQuestion = null),
              child: Text(
                'Use a different username',
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(AppPalette palette) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: palette.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 40, color: palette.success),
        ),
        const SizedBox(height: 20),
        Text(
          'Password Reset',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: palette.textMain,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your password has been updated. You can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: palette.textSecondary),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => context.go('/sign-in'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Back to Sign In',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}