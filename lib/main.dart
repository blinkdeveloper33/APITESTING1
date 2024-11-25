import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  String? linkToken;
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

  Future<void> _storeToken(String newToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', newToken);
  }

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
      setState(() {
        output = 'Error: $e';
      });
    }
  }

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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        linkToken = data['linkToken'];

        setState(() {
          output = 'Link Token generated. Redirecting to Plaid Link...';
        });

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaidWebView(initialUrl: linkToken!),
          ),
        );
      } else {
        setState(() => output = 'Failed to generate Link Token: ${response.body}');
      }
    } catch (e) {
      setState(() => output = 'Error: $e');
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
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  loginUser(emailController.text, passwordController.text),
              child: const Text('Login User'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: createLinkToken,
              child: const Text('Generate Link Token'),
            ),
            const SizedBox(height: 20),
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

class PlaidWebView extends StatelessWidget {
  final String initialUrl;

  const PlaidWebView({super.key, required this.initialUrl});

  @override
  Widget build(BuildContext context) {
    final String plaidUrl = 'https://cdn.plaid.com/link/v2/stable/link.html?isWebview=true&token=$initialUrl';
    
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('plaidlink://')) {
              Navigator.of(context).pop();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(plaidUrl));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Your Bank'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
