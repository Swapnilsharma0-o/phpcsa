import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:phpcsa/screens/install_screen.dart';
import 'package:process_run/process_run.dart';

class InventorySetupScreen extends StatefulWidget {
  const InventorySetupScreen({Key? key}) : super(key: key);

  @override
  _InventorySetupScreenState createState() => _InventorySetupScreenState();
}

class _InventorySetupScreenState extends State<InventorySetupScreen> {
  String? _inventoryFilePath;
  bool _isRunning = false;
  String _output = '';

  Future<void> _installAnsible() async {
    setState(() {
      _isRunning = true;
      _output = '';
    });

    try {
      // Install Ansible
      await Process.run('sudo', ['apt-get', 'update']);
      await Process.run('sudo', ['apt-get', 'install', '-y', 'ansible']);

      // Create directories
      final playbookDir = Directory('/home/`whoami`/phpcsa/cluster/playbooks');
      if (!await playbookDir.exists()) {
        await playbookDir.create(recursive: true);
      }

      setState(() {
        _output = 'Ansible installed and playbook directory created.';
      });
    } catch (e) {
      setState(() {
        _output = 'Error installing Ansible: $e';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _pickInventoryFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      setState(() {
        _inventoryFilePath = result.files.single.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ansible Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _pickInventoryFile,
              child: const Text('Pick Inventory File'),
            ),
            if (_inventoryFilePath != null)
              Text('Selected Inventory File: $_inventoryFilePath'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRunning ? null : _installAnsible,
              child: _isRunning
                  ? const CircularProgressIndicator()
                  : const Text('Install Ansible'),
            ),
            if (_output.isNotEmpty)
              Text(
                'Output:\n$_output',
                style: const TextStyle(color: Colors.green),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ServiceInstallScreen(),
                  ),
                );
              },
              child: const Text('Go to Service Installation'),
            ),
          ],
        ),
      ),
    );
  }
}
