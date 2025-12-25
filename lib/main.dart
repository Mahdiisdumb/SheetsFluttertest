import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:device_info_plus/device_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SheetsUploader(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SheetsUploader extends StatefulWidget {
  const SheetsUploader({super.key});

  @override
  State<SheetsUploader> createState() => _SheetsUploaderState();
}

class _SheetsUploaderState extends State<SheetsUploader> {
  final rowCtrl = TextEditingController();
  final colCtrl = TextEditingController();
  final dataCtrl = TextEditingController();

  bool busy = false;

  Future<String> getUploaderName() async {
    if (kIsWeb) {
      throw UnsupportedError('Web has no environment username');
    }

    if (Platform.isWindows) {
      return Platform.environment['USERNAME'] ?? 'UnknownWindowsUser';
    }

    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      return '${info.manufacturer} ${info.model}';
    }

    return 'UnknownDevice';
  }

  Future<void> upload() async {
    if (kIsWeb) {
      _snack(
        'Service accounts and environment usernames do not work on Web.',
        error: true,
      );
      return;
    }

    final row = int.tryParse(rowCtrl.text.trim());
    final col = colCtrl.text.trim().toUpperCase();
    final rawValue = dataCtrl.text;

    if (row == null || row <= 0 || col.isEmpty || rawValue.isEmpty) {
      _snack('Invalid input', error: true);
      return;
    }

    setState(() => busy = true);
    auth.AutoRefreshingAuthClient? client;

    try {
      final uploader = await getUploaderName();

      final jsonStr =
          await rootBundle.loadString('assets/credential.json');
      final credsMap = json.decode(jsonStr);

      final creds =
          auth.ServiceAccountCredentials.fromJson(credsMap);

      client = await auth.clientViaServiceAccount(
        creds,
        [sheets.SheetsApi.spreadsheetsScope],
      );

      final api = sheets.SheetsApi(client);

      const spreadsheetId =
          '1MwBfX4ZgM2Vr4LdT0ovSYBTb5pVkLuSWzfPR90zPK-Q';

      final range = '$col$row';

      // ---- CHECK EXISTING ----
      final existing = await api.spreadsheets.values.get(
        spreadsheetId,
        range,
      );

      final hasData = existing.values != null &&
          existing.values!.isNotEmpty &&
          existing.values!.first.isNotEmpty &&
          existing.values!.first.first.toString().isNotEmpty;

      if (hasData) {
        _snack(
          'Cell $range already contains data',
          error: true,
        );
        return;
      }

      final finalValue = '$rawValue ($uploader)';

      final body = sheets.ValueRange(
        values: [
          [finalValue]
        ],
      );

      await api.spreadsheets.values.update(
        body,
        spreadsheetId,
        range,
        valueInputOption: 'RAW',
      );

      _snack('Upload successful');
    } catch (e) {
      _snack('Upload failed:\n$e', error: true);
    } finally {
      client?.close();
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sheets Uploader Made by Mahdiisdumb')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Enter the row, column, and value to upload to the Google Sheet.',
            ),
            TextField(
              controller: rowCtrl,
              decoration: const InputDecoration(labelText: 'Row'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: colCtrl,
              decoration: const InputDecoration(labelText: 'Column'),
            ),
            TextField(
              controller: dataCtrl,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: busy ? null : upload,
              child: busy
                  ? const CircularProgressIndicator()
                  : const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }
}
