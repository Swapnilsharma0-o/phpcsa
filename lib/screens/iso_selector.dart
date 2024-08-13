import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class IsoSelector extends StatefulWidget {
  const IsoSelector({Key? key}) : super(key: key);

  @override
  _IsoSelectorState createState() => _IsoSelectorState();
}

class _IsoSelectorState extends State<IsoSelector> {
  String? _selectedFilePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(400, 6, 400, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset(
                    'lib/assets/img/tp4.png',
                    width: 600,
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Select ISO Image:', style: TextStyle(fontSize: 18)),
                ElevatedButton(
                  onPressed: _selectFile,
                  child: const Text('Pick File'),
                ),
                if (_selectedFilePath != null)
                  Text('Selected File: $_selectedFilePath'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Navigate back
                      },
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (_selectedFilePath != null) {
                          _copyFileToCurrentDirectory();
                        }
                        // Add your navigation logic for the "Next" button here
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NextPage(), // Replace with the actual next page
                          ),
                        );
                      },
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _copyFileToCurrentDirectory() async {
    if (_selectedFilePath == null) return;

    final filePath = _selectedFilePath!;
    final fileName = 'run_iso.iso'; // Extract file name from path
    final currentDirectory = Directory.current.path; // Get the current directory
    final destinationPath = '$currentDirectory/$fileName'; // Path for the copied file

    final command = Platform.isWindows
        ? 'copy "$filePath" "$destinationPath"'
        : 'cp "$filePath" "$destinationPath"';

    try {
      final result = await Process.run('sh', ['-c', command]);
      if (result.exitCode == 0) {
        print('File copied to $destinationPath');
      } else {
        print('Error copying file: ${result.stderr}');
      }
    } catch (e) {
      print('Error running command: $e');
    }
  }
}

// Replace this with your actual next page widget
class NextPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Next Page'),
      ),
      body: Center(
        child: Text('This is the next page.'),
      ),
    );
  }
}
