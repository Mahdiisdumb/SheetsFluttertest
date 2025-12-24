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

    // Load service account credentials
    final credentialsJson =
        json.decode(await rootBundle.loadString('assets/credentials.json'));

    final accountCredentials = auth.ServiceAccountCredentials.fromJson(credentialsJson);
    final scopes = [sheets.SheetsApi.spreadsheetsScope];

    // Create authenticated client
    final client = await auth.clientViaServiceAccount(accountCredentials, scopes);

    final sheetsApi = sheets.SheetsApi(client);

    final spreadsheetId = '1MwBfX4ZgM2Vr4LdT0ovSYBTb5pVkLuSWzfPR90zPK-Q';
    final row = int.parse(rowController.text);
    final col = colController.text.toUpperCase(); // e.g., "A", "B"
    final value = dataController.text;

    final range = '$col$row';

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

    client.close();

    setState(() => uploading = false);
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
              child: uploading ? CircularProgressIndicator() : Text('Upload'),
            )
          ],
        ),
      ),
    );
  }
}
