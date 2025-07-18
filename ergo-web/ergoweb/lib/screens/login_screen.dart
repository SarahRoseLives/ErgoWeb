import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/login_response.dart';
import '../main_layout.dart';
import '../services/fingerprint_service.dart';
import '../utils/motd.dart';
import 'package:get_it/get_it.dart';

class LoginScreen extends StatefulWidget {
  final bool showExpiredMessage;
  const LoginScreen({super.key, this.showExpiredMessage = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); // For registration
  bool _loading = false;
  String? _message;
  bool _isRegisterMode = false; // To toggle between Login and Register
  final ApiService _apiService = ApiService();
  final FingerprintService _fingerprintService = FingerprintService();
  bool _fingerprintLoginAvailable = false;

  late final String _motd;

  @override
  void initState() {
    super.initState();
    _motd = Motd.random();
    _checkFingerprintAvailability();

    if (widget.showExpiredMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _message = 'Your session has expired. Please login again.';
          });
        }
      });
    }
  }

  Future<void> _checkFingerprintAvailability() async {
    final isEnabled = await _fingerprintService.isFingerprintEnabled();
    if (mounted) {
      setState(() {
        _fingerprintLoginAvailable = isEnabled;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose(); // Dispose the new controller
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _message = null; // Clear previous messages
      _formKey.currentState?.reset(); // Reset form validation state
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _message = "Registering account...";
    });

    try {
      final response = await _apiService.register(
        _usernameController.text.trim(),
        _passwordController.text,
        email: _emailController.text.trim(),
      );

      if (response['success'] == true) {
        setState(() {
          _message = "Registration successful! Logging in...";
        });
        // On successful registration, automatically attempt to log in.
        await _login();
      } else {
        setState(() {
          _message = response['message'] ?? 'An unknown registration error occurred.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = "Error: $e";
        _loading = false;
      });
    }
  }

  Future<void> _loginWithFingerprint() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _message = "Authenticating...";
      });
    }

    final authenticated = await _fingerprintService.authenticate(
        localizedReason: 'Authenticate to log in to ergoweb');

    if (!authenticated) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'Authentication failed.';
        });
      }
      return;
    }

    final credentials = await _fingerprintService.getCredentials();
    if (credentials != null) {
      // Use the stored credentials to log in
      _usernameController.text = credentials['username']!;
      _passwordController.text = credentials['password']!;
      await _login();
    } else {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'Saved credentials not found. Please log in manually.';
        });
      }
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      if (_message == null || !_message!.contains("Logging in...")) {
        _message = null;
      }
    });

    try {
      final LoginResponse response = await _apiService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (response.success && response.token != null) {
        final token = response.token!;
        final username = _usernameController.text.trim();

        GetIt.instance<ApiService>().setToken(token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('username', username);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ergowebLayout(username: username, token: token),
            ),
          );
        }
      } else {
        setState(() {
          _message = response.message;
        });
      }
    } catch (e) {
      setState(() {
        _message = "Error: $e";
      });
    } finally {
      if (mounted && _message != "Registration successful! Logging in...") {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF313338),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 370,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2D31),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black,
                  blurRadius: 30,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 84,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'ergoweb',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5865F2),
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          blurRadius: 12,
                          color: Color(0xFF5865F2),
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _motd,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF232428),
                      labelText: 'Username',
                      prefixIcon:
                          const Icon(Icons.person, color: Color(0xFF5865F2)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter username'
                        : null,
                    enabled: !_loading,
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (_isRegisterMode) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF232428),
                        labelText: 'Email (Optional)',
                        prefixIcon:
                            const Icon(Icons.email, color: Color(0xFF5865F2)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            !RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                                .hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF232428),
                      labelText: 'Password',
                      prefixIcon:
                          const Icon(Icons.lock, color: Color(0xFF5865F2)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Enter password' : null,
                    obscureText: true,
                    enabled: !_loading,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5865F2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      icon: Icon(_isRegisterMode ? Icons.person_add : Icons.login,
                          color: Colors.white),
                      label: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(_isRegisterMode ? 'Register' : 'Login',
                              style: const TextStyle(color: Colors.white)),
                      onPressed: _loading
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                if (_isRegisterMode) {
                                  _register();
                                } else {
                                  _login();
                                }
                              }
                            },
                    ),
                  ),
                  if (_fingerprintLoginAvailable && !_isRegisterMode) ...[
                    const SizedBox(height: 12),
                    const Text('or', style: TextStyle(color: Colors.white54)),
                    const SizedBox(height: 12),
                    IconButton(
                      icon: const Icon(Icons.fingerprint,
                          color: Colors.white, size: 52),
                      onPressed: _loading ? null : _loginWithFingerprint,
                      tooltip: 'Login with Fingerprint',
                      style: IconButton.styleFrom(
                        side: const BorderSide(color: Colors.white24, width: 1),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : _toggleMode,
                    child: Text(
                      _isRegisterMode
                          ? 'Already have an account? Login'
                          : "Don't have an account? Register",
                      style: const TextStyle(color: Color(0xFF5865F2)),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _message!.startsWith('Your session')
                            ? Colors.orangeAccent
                            : (_message!
                                    .toLowerCase()
                                    .contains("authenticating") ||
                                _message!.toLowerCase().contains("successful"))
                                ? Colors.lightGreenAccent
                                : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}