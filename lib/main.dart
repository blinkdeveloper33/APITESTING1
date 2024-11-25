import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:plaid_flutter/plaid_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: "assets/.env");
    debugPrint("Environment variables loaded successfully.");
  } catch (e) {
    debugPrint("Error loading .env file: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plaid Integration',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ApiTestScreen(),
    );
  }
}

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:5000/api';
  String? token;
  String? userId;
  String output = 'Output will be shown here';

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStoredToken();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Load the stored token from SharedPreferences
  Future<void> _loadStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('token');
    if (storedToken != null && !JwtDecoder.isExpired(storedToken)) {
      setState(() {
        token = storedToken;
        userId = JwtDecoder.decode(token!)['id'];
        output = 'User logged in. User ID: $userId';
      });
    } else {
      await prefs.remove('token');
    }
  }

  // Store the token in SharedPreferences
  Future<void> _storeToken(String newToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', newToken);
  }

  // Login the user by sending credentials to the backend
  Future<void> loginUser(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        output = 'Please fill in all fields';
      });
      return;
    }

    setState(() {
      output = 'Logging in...';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['token'];
        userId = JwtDecoder.decode(token!)['id'];

        await _storeToken(token!);

        setState(() {
          output = 'Login successful. User ID: $userId';
        });
      } else {
        setState(() {
          output = 'Login failed: ${response.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        output = 'Error: $e';
      });
    }
  }

  // Create a Plaid link token by communicating with the backend
  Future<void> createLinkToken() async {
    if (token == null || userId == null) {
      setState(() => output = 'Please login first');
      return;
    }

    setState(() {
      output = 'Generating Link Token...';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/plaid/create_link_token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userId': userId}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final linkToken = data['linkToken'];

        setState(() {
          output = 'Link Token generated. Opening Plaid Link...';
        });

        await openPlaidLink(linkToken);
      } else {
        setState(() => output = 'Failed to generate Link Token: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => output = 'Error: $e');
    }
  }

  // Exchange the public token received from Plaid for an access token
  Future<void> exchangePublicToken(String publicToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/plaid/exchange_public_token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'publicToken': publicToken}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          output = 'Public token exchanged successfully';
        });
        debugPrint('Exchange successful: $data');
      } else {
        setState(() {
          output = 'Failed to exchange public token: ${response.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        output = 'Error exchanging public token: $e';
      });
    }
  }

  // Open the Plaid Link using the provided link token
  Future<void> openPlaidLink(String linkToken) async {
    try {
      // Create configuration with only the required token parameter
      final configuration = LinkTokenConfiguration(
        token: linkToken,
      );

      // Initialize Plaid Link
      await PlaidLink.create(configuration: configuration);

      // Open Plaid Link without assigning the result since it returns void
      await PlaidLink.open();

      // Set up event listeners
      PlaidLink.onSuccess.listen((LinkSuccess success) async {
        debugPrint('Link Success - Public Token: ${success.publicToken}');
        await exchangePublicToken(success.publicToken);
      });

      PlaidLink.onExit.listen((LinkExit exit) {
        if (exit.error != null) {
          debugPrint('Link Error: ${exit.error?.displayMessage}');
          setState(() {
            output = 'Link Error: ${exit.error?.displayMessage}';
          });
        } else {
          debugPrint('Link Exit - User closed Plaid Link');
          setState(() {
            output = 'Link closed by user';
          });
        }
      });

      PlaidLink.onEvent.listen((LinkEvent event) {
        debugPrint('Link Event: ${event.name}');
        // Optionally, you can handle different events here
        // For example, show a toast or update the UI based on event.name
      });

      // Update the UI to indicate that Plaid Link has been opened
      setState(() {
        output = 'Plaid Link opened successfully';
      });
    } catch (e) {
      debugPrint('Error creating/opening Plaid Link: $e');
      if (!mounted) return;
      setState(() {
        output = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plaid API Integration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Email Input Field
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Password Input Field
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),

            // Login Button
            ElevatedButton(
              onPressed: () =>
                  loginUser(emailController.text, passwordController.text),
              child: const Text('Login User'),
            ),
            const SizedBox(height: 16),

            // Generate Link Token Button
            ElevatedButton(
              onPressed: createLinkToken,
              child: const Text('Generate Link Token'),
            ),
            const SizedBox(height: 20),

            // Output Display Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(output),
            ),
          ],
        ),
      ),
    );
  }
}
