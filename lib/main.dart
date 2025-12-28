import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sheets Chatroom',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  
  bool isLogin = true;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        body: Center(
          child: Text(
            'Service accounts do not work on Web.\nPlease use mobile or desktop.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Login' : 'Sign Up'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            if (!isLogin) ...[
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: busy ? null : () => isLogin ? _login() : _signup(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isLogin ? 'Login' : 'Sign Up'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                        isLogin = !isLogin;
                        emailCtrl.clear();
                      }),
              child: Text(isLogin
                  ? 'Don\'t have an account? Sign Up'
                  : 'Already have an account? Login'),
            ),
            if (isLogin) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: busy ? null : _showResetDialog,
                child: const Text('Forgot Password?'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    final username = usernameCtrl.text.trim();
    final password = passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _snack('Please enter username and password', error: true);
      return;
    }

    setState(() => busy = true);
    auth.AutoRefreshingAuthClient? client;

    try {
      client = await _getClient();
      final api = sheets.SheetsApi(client);
      const spreadsheetId = '1MwBfX4ZgM2Vr4LdT0ovSYBTb5pVkLuSWzfPR90zPK-Q';

      // Get all users from USERS sheet
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        'USERS!A:C',
      );

      if (response.values == null || response.values!.isEmpty) {
        _snack('No users found. Please sign up first.', error: true);
        return;
      }

      // Debug: show how many users found
      print('Found ${response.values!.length} rows in USERS sheet');

      // Find user (start from row 0 or 1 depending on if there's a header)
      for (int i = 0; i < response.values!.length; i++) {
        final row = response.values![i];
        print('Row $i: $row (length: ${row.length})'); // Debug print
        
        // Handle case where data might be in one cell with tabs
        if (row.length == 1 && row[0].toString().contains('\t')) {
          final parts = row[0].toString().split('\t');
          if (parts.length >= 2) {
            final sheetUsername = parts[0].trim();
            final sheetPassword = parts[1].trim();
            
            print('Tab-separated data: "$sheetUsername" == "$username" && "$sheetPassword" == "$password"');
            
            if (sheetUsername == username && sheetPassword == password) {
              // Login successful
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      username: username,
                      email: parts.length > 2 ? parts[2].trim() : '',
                    ),
                  ),
                );
              }
              return;
            }
          }
        } else if (row.length >= 2) {
          final sheetUsername = row[0].toString().trim();
          final sheetPassword = row[1].toString().trim();
          
          print('Normal cells: "$sheetUsername" == "$username" && "$sheetPassword" == "$password"');
          
          if (sheetUsername == username && sheetPassword == password) {
            // Login successful
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    username: username,
                    email: row.length > 2 ? row[2].toString() : '',
                  ),
                ),
              );
            }
            return;
          }
        }
      }

      _snack('Invalid username or password', error: true);
    } catch (e) {
      _snack('Login failed: $e', error: true);
      print('Login error: $e');
    } finally {
      client?.close();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _signup() async {
    final username = usernameCtrl.text.trim();
    final password = passwordCtrl.text.trim();
    final email = emailCtrl.text.trim();

    if (username.isEmpty || password.isEmpty || email.isEmpty) {
      _snack('Please fill in all fields', error: true);
      return;
    }

    setState(() => busy = true);
    auth.AutoRefreshingAuthClient? client;

    try {
      client = await _getClient();
      final api = sheets.SheetsApi(client);
      const spreadsheetId = '1MwBfX4ZgM2Vr4LdT0ovSYBTb5pVkLuSWzfPR90zPK-Q';

      // Check if username exists
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        'USERS!A:A',
      );

      if (response.values != null) {
        for (int i = 0; i < response.values!.length; i++) {
          if (response.values![i].isNotEmpty &&
              response.values![i][0].toString().trim() == username) {
            _snack('Username already exists', error: true);
            return;
          }
        }
      }

      // Add new user
      final body = sheets.ValueRange(values: [
        [username, password, email]
      ]);

      await api.spreadsheets.values.append(
        body,
        spreadsheetId,
        'USERS!A:C',
        valueInputOption: 'RAW',
      );

      _snack('Account created successfully!');
      setState(() => isLogin = true);
      passwordCtrl.clear();
      emailCtrl.clear();
    } catch (e) {
      _snack('Signup failed: $e', error: true);
    } finally {
      client?.close();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _showResetDialog() async {
    final resetUsernameCtrl = TextEditingController();
    final resetEmailCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your username and email to request a password reset.'),
            const SizedBox(height: 16),
            TextField(
              controller: resetUsernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _submitResetRequest(
        resetUsernameCtrl.text.trim(),
        resetEmailCtrl.text.trim(),
      );
    }
  }

  Future<void> _submitResetRequest(String username, String email) async {
    if (username.isEmpty || email.isEmpty) {
      _snack('Please enter username and email', error: true);
      return;
    }

    setState(() => busy = true);
    auth.AutoRefreshingAuthClient? client;

    try {
      client = await _getClient();
      final api = sheets.SheetsApi(client);
      const spreadsheetId = '1MwBfX4ZgM2Vr4LdT0ovSYBTb5pVkLuSWzfPR90zPK-Q';

      final timestamp = DateTime.now().toIso8601String();
      final body = sheets.ValueRange(values: [
        [username, email, timestamp]
      ]);

      await api.spreadsheets.values.append(
        body,
        spreadsheetId,
        'USERREQUESTS!A:C',
        valueInputOption: 'RAW',
      );

      _snack('Password reset request submitted. Check your email.');
    } catch (e) {
      _snack('Request failed: $e', error: true);
    } finally {
      client?.close();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<auth.AutoRefreshingAuthClient> _getClient() async {
    final jsonStr = await rootBundle.loadString('assets/credential.json');
    final credsMap = json.decode(jsonStr);
    final creds = auth.ServiceAccountCredentials.fromJson(credsMap);

    return await auth.clientViaServiceAccount(
      creds,
      [sheets.SheetsApi.spreadsheetsScope],
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String username;
  final String email;

  const ChatScreen({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  List<Map<String, String>> messages = [];
  Timer? refreshTimer;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _loadMessages(),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    messageCtrl.dispose();
    scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    auth.AutoRefreshingAuthClient? client;

    try {
      client = await _getClient();
      final api = sheets.SheetsApi(client);
      const spreadsheetId = '1MwBfX4ZgM2Vr4LdT0ovSYBTb5pVkLuSWzfPR90zPK-Q';

      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        'CHATS!A:C',
      );

      if (response.values != null && mounted) {
        final newMessages = <Map<String, String>>[];
        // Start from index 0 to include all messages (no header row skip)
        for (int i = 0; i < response.values!.length; i++) {
          final row = response.values![i];
          
          // Handle tab-separated data in one cell
          if (row.length == 1 && row[0].toString().contains('\t')) {
            final parts = row[0].toString().split('\t');
            if (parts.length >= 3) {
              newMessages.add({
                'username': parts[0].trim(),
                'message': parts[1].trim(),
                'timestamp': parts[2].trim(),
              });
            }
          } else if (row.length >= 3) {
            // Normal cell-separated data
            newMessages.add({
              'username': row[0].toString().trim(),
              'message': row[1].toString().trim(),
              'timestamp': row[2].toString().trim(),
            });
          } else if (row.length == 2) {
            // Handle case with no timestamp
            newMessages.add({
              'username': row[0].toString().trim(),
              'message': row[1].toString().trim(),
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
        }

        setState(() => messages = newMessages);
        
        // Auto-scroll to bottom on new messages
        if (scrollCtrl.hasClients) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (scrollCtrl.hasClients) {
              scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
            }
          });
        }
      }
    } catch (e) {
      print('Load messages error: $e');
      // Silent fail for refresh
    } finally {
      client?.close();
    }
  }

  Future<void> _sendMessage() async {
    final message = messageCtrl.text.trim();
    if (message.isEmpty) return;

    setState(() => sending = true);
    auth.AutoRefreshingAuthClient? client;

    try {
      client = await _getClient();
      final api = sheets.SheetsApi(client);
      const spreadsheetId = '1MwBfX4ZgM2Vr4LdT0ovSYBTb5pVkLuSWzfPR90zPK-Q';

      final timestamp = DateTime.now().toIso8601String();
      final body = sheets.ValueRange(values: [
        [widget.username, message, timestamp]
      ]);

      await api.spreadsheets.values.append(
        body,
        spreadsheetId,
        'CHATS!A:C',
        valueInputOption: 'RAW',
      );

      messageCtrl.clear();
      await _loadMessages();
    } catch (e) {
      _snack('Failed to send message: $e', error: true);
    } finally {
      client?.close();
      if (mounted) setState(() => sending = false);
    }
  }

  Future<auth.AutoRefreshingAuthClient> _getClient() async {
    final jsonStr = await rootBundle.loadString('assets/credential.json');
    final credsMap = json.decode(jsonStr);
    final creds = auth.ServiceAccountCredentials.fromJson(credsMap);

    return await auth.clientViaServiceAccount(
      creds,
      [sheets.SheetsApi.spreadsheetsScope],
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat - ${widget.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final isMe = msg['username'] == widget.username;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.blue[100]
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Text(
                                  msg['username']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              Text(msg['message']!),
                              Text(
                                _formatTimestamp(msg['timestamp']!),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: sending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: sending ? null : _sendMessage,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}