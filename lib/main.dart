import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:flutter/services.dart' show rootBundle; 

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sheets Uploader',
      home: const SheetsUploader(),
    );
  }
} 

class SheetsUploader extends StatefulWidget {
  const SheetsUploader({super.key});

  @override
  State<SheetsUploader> createState() => _SheetsUploaderState();
}

class _SheetsUploaderState extends State<SheetsUploader> {
  final rowController = TextEditingController();
  final colController = TextEditingController();
  final dataController = TextEditingController();

  bool uploading = false;

  Future<void> uploadToSheet() async {
    setState(() => uploading = true);

    auth.AutoRefreshingAuthClient? client;
    Map<String, dynamic>? credentialsJson;
    String? serviceAccountEmail;

    try {
      // Validate inputs early to fail fast
      final rowText = rowController.text.trim();
      final colText = colController.text.trim().toUpperCase();
      if (rowText.isEmpty || colText.isEmpty) {
        showSnack('Row and Column are required', isError: true);
        return;
      }

      final row = int.tryParse(rowText);
      if (row == null || row <= 0) {
        showSnack('Row must be a positive integer', isError: true);
        return;
      }

      final value = dataController.text;

      // Load service account credentials
      final credsString = await rootBundle.loadString('assets/credentials.json');
      credentialsJson = json.decode(credsString) as Map<String, dynamic>;
      serviceAccountEmail = credentialsJson['client_email'] as String?;

      final accountCredentials = auth.ServiceAccountCredentials.fromJson(credentialsJson);
      final scopes = [sheets.SheetsApi.spreadsheetsScope];

      // Create authenticated client (handle auth-specific errors with helpful guidance)
      try {
        client = await auth.clientViaServiceAccount(accountCredentials, scopes);
      } catch (authErr, authSt) {
        final authMsg = authErr.toString().toLowerCase();
        debugPrint('Authentication error: $authErr');
        debugPrint(authSt.toString());

        if (authMsg.contains('400') || authMsg.contains('bad request') || authMsg.contains('invalid_grant') || authMsg.contains('invalid_client') || authMsg.contains('invalid_scope')) {
          showSnack('Failed to obtain access credentials (HTTP 400). Common causes: use a service account JSON key (not OAuth client), enable the Sheets API in GCP, or share the spreadsheet with the service account email: ${serviceAccountEmail ?? '<service-account-email>'}', isError: true);
        } else {
          showSnack('Authentication failed: ${authErr.toString()}', isError: true);
        }
        return; // stop further processing - finally block will run
      }

      final sheetsApi = sheets.SheetsApi(client);

      final spreadsheetId = '1MwBfX4ZgM2Vr4LdT0ovSYBTb5pVkLuSWzfPR90zPK-Q';
      final range = '$colText$row';

      final request = sheets.ValueRange.fromJson({
        'range': range,
        'values': [
          [value]
        ]
      });

      await sheetsApi.spreadsheets.values.update(
        request,
        spreadsheetId,
        range,
        valueInputOption: 'RAW',
      );

      showSnack('Upload successful');
    } on FlutterError catch (e) {
      // Asset/credential reading errors
      debugPrint('Credential load error: ${e.toString()}');
      showSnack('Could not load credentials.json. Make sure the file exists in assets and is listed in pubspec.yaml', isError: true);
    } catch (e, st) {
      final msg = e.toString().toLowerCase();
      debugPrint('Upload error: $e');
      debugPrint(st.toString());

      if (msg.contains('400') || msg.contains('bad request') || msg.contains('invalid_grant') || msg.contains('invalid_client') || msg.contains('invalid_scope')) {
        showSnack('Failed to obtain access credentials (HTTP 400). Common causes: use a service account JSON key (not OAuth client), enable the Sheets API in GCP, or share the spreadsheet with the service account email: ${serviceAccountEmail ?? '<service-account-email>'}', isError: true);
      } else if (msg.contains('403') || msg.contains('forbidden') || msg.contains('permission')) {
        showSnack('Permission denied (403). Make sure the spreadsheet is shared with the service account email: ${serviceAccountEmail ?? '<service-account-email>'}', isError: true);
      } else {
        showSnack('Upload failed: ${e.toString()}', isError: true);
      }
    } finally {
      client?.close();
      if (mounted) setState(() => uploading = false);
    }
  }

  void showSnack(String message, {bool isError = false}) {
    final snack = SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : null,
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sheets Uploader')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: rowController,
              decoration: InputDecoration(labelText: 'Row (number)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: colController,
              decoration: InputDecoration(labelText: 'Column (letter)'),
            ),
            TextField(
              controller: dataController,
              decoration: InputDecoration(labelText: 'Data'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: uploading ? null : uploadToSheet,
              child: uploading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Upload'),
            )
          ],
        ),
      ),
    );
  }
}
