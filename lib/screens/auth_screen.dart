import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';

enum _AuthMode { login, register, forgot }

enum _AuthType { email, phone }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.initialMode = 'login',
    this.authService,
  });

  final String initialMode;
  final AuthService? authService;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  late _AuthMode _mode =
      widget.initialMode == 'register' ? _AuthMode.register : _AuthMode.login;
  _AuthType _authType = _AuthType.email;

  final _displayNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _existingEmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _adminCodeCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _existingEmailCtrl.dispose();
    _passwordCtrl.dispose();
    _adminCodeCtrl.dispose();
    super.dispose();
  }

  void _resetTransientState() {
    setState(() {
      _error = null;
      _success = null;
      _adminCodeCtrl.clear();
      _phoneCtrl.clear();
      _existingEmailCtrl.clear();
    });
  }

  void _switchAuthType(_AuthType type) {
    if (type == _authType) return;
    HapticFeedback.selectionClick();
    setState(() {
      _authType = type;
      _error = null;
      _emailCtrl.clear();
      _phoneCtrl.clear();
      _existingEmailCtrl.clear();
    });
  }

  void _switchMode(_AuthMode mode) {
    HapticFeedback.selectionClick();
    setState(() => _mode = mode);
    _resetTransientState();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_mode == _AuthMode.register) {
        await _authService.register(
          usePhone: _authType == _AuthType.phone,
          displayName: _displayNameCtrl.text,
          email: _emailCtrl.text,
          phone: _phoneCtrl.text,
          existingEmail: _existingEmailCtrl.text,
          password: _passwordCtrl.text,
          adminCode: _adminCodeCtrl.text,
        );
      } else {
        await _authService.login(
          usePhone: _authType == _AuthType.phone,
          email: _emailCtrl.text,
          phone: _phoneCtrl.text,
          password: _passwordCtrl.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mode == _AuthMode.register
              ? 'Account created! A lead usher will approve your access shortly.'
              : 'Welcome back.'),
        ),
      );
    } on AuthException catch (e) {
      HapticFeedback.mediumImpact();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitForgotPassword() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.sendPasswordReset(_emailCtrl.text);
      setState(() => _success = 'Reset link sent! Check your email inbox.');
    } on AuthException catch (e) {
      HapticFeedback.mediumImpact();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.slate800,
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LogoBadge(),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          _titleFor(_mode),
                          key: ValueKey(_mode),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 26,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Servant Leadership Portal',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: AppColors.amber600.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _mode == _AuthMode.forgot
                              ? _buildForgotForm()
                              : _buildLoginRegisterForm(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleFor(_AuthMode mode) => switch (mode) {
        _AuthMode.forgot => 'Reset Password',
        _AuthMode.register => 'Join the Guard',
        _AuthMode.login => 'Guardians Login',
      };

  Widget _buildForgotForm() {
    return Column(
      key: const ValueKey('forgot'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AuthTextField(
          controller: _emailCtrl,
          hint: 'Email Address',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _ErrorBanner(message: _error),
        _SuccessBanner(message: _success),
        const SizedBox(height: 6),
        if (_success == null)
          _SubmitButton(
            label: 'Send Reset Link',
            loading: _loading,
            onTap: _submitForgotPassword,
          ),
        const SizedBox(height: 20),
        _TextLink(
          label: 'Back to Login',
          onTap: () => _switchMode(_AuthMode.login),
        ),
      ],
    );
  }

  Widget _buildLoginRegisterForm() {
    final isRegister = _mode == _AuthMode.register;
    return Column(
      key: ValueKey('${_mode}_$_authType'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AuthTypeToggle(
          selected: _authType,
          onChanged: _switchAuthType,
        ),
        const SizedBox(height: 18),
        if (isRegister) ...[
          _AuthTextField(controller: _displayNameCtrl, hint: 'Full Name'),
          const SizedBox(height: 12),
        ],
        if (_authType == _AuthType.email)
          _AuthTextField(
            controller: _emailCtrl,
            hint: 'Email Address',
            keyboardType: TextInputType.emailAddress,
          )
        else ...[
          _AuthTextField(
            controller: _phoneCtrl,
            hint: 'Phone Number (used to sign in)',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 6),
          if (!isRegister)
            _HintText('Enter the phone number you registered with.'),
          if (isRegister) ...[
            const SizedBox(height: 12),
            _AuthTextField(
              controller: _existingEmailCtrl,
              hint: 'Already have an email account? Enter it here',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 6),
            _HintText(
              'Optional — links your phone to an existing email registration so you only appear once in the roster.',
            ),
          ],
        ],
        const SizedBox(height: 12),
        _AuthTextField(
          controller: _passwordCtrl,
          hint: 'Password',
          obscureText: _obscurePassword,
          suffix: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 18,
              color: AppColors.slate400,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        if (isRegister) ...[
          const SizedBox(height: 12),
          _AuthTextField(controller: _adminCodeCtrl, hint: 'Admin Code (optional)'),
        ],
        if (!isRegister && _authType == _AuthType.email) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: _TextLink(
              label: 'Forgot Password?',
              onTap: () => _switchMode(_AuthMode.forgot),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _ErrorBanner(message: _error),
        const SizedBox(height: 8),
        _SubmitButton(
          label: isRegister ? 'Create Account' : 'Enter Gate',
          loading: _loading,
          onTap: _submit,
        ),
        const SizedBox(height: 20),
        _TextLink(
          label: isRegister
              ? 'Already have an account? Log In'
              : 'Need an account? Register',
          onTap: () =>
              _switchMode(isRegister ? _AuthMode.login : _AuthMode.register),
        ),
      ],
    );
  }
}

class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.amber100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber800.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
      ),
    );
  }
}

class _AuthTypeToggle extends StatelessWidget {
  const _AuthTypeToggle({required this.selected, required this.onChanged});

  final _AuthType selected;
  final void Function(_AuthType) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.amber50.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleTab(
              label: 'Use Email',
              selected: selected == _AuthType.email,
              onTap: () => onChanged(_AuthType.email),
            ),
          ),
          Expanded(
            child: _ToggleTab(
              label: 'No Email',
              selected: selected == _AuthType.phone,
              onTap: () => onChanged(_AuthType.phone),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.slate900.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: selected ? AppColors.amber800 : AppColors.slate400,
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.slate800),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.slate400),
        filled: true,
        fillColor: AppColors.amber50.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10, height: 1.4, color: AppColors.slate400),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatefulWidget {
  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.loading;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: disabled
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: disabled ? 0.7 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.amber700,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.amber700.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: widget.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    widget.label.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: AppColors.amber800.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
