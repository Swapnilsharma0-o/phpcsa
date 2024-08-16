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
  var _currentUser;
  List<String> _clientIps = [];

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    try {
      final result = await Process.run('whoami', []);
      setState(() {
        _currentUser = result.stdout.trim();
      });
    } catch (e) {
      setState(() {
        _output = 'Error fetching current user: $e';
      });
    }
  }

  Future<void> _installSshpass() async {
    setState(() {
      _output += 'Checking and installing sshpass...\n';
    });

    try {
      final checkResult = await Process.run('which', ['sshpass']);
      if (checkResult.exitCode != 0) {
        final installResult =
            await Process.run('sudo', ['apt-get', 'install', '-y', 'sshpass']);
        if (installResult.exitCode == 0) {
          setState(() {
            _output += 'sshpass installed successfully.\n';
          });
        } else {
          setState(() {
            _output += 'Failed to install sshpass: ${installResult.stderr}\n';
          });
          return;
        }
      } else {
        setState(() {
          _output += 'sshpass is already installed.\n';
        });
      }
    } catch (e) {
      setState(() {
        _output += 'Error installing sshpass: $e\n';
      });
    }
  }

  Future<void> _setupPasswordlessSSH() async {
    setState(() {
      _output += 'Setting up passwordless SSH...\n';
    });

    try {
      final keyGenResult = await Process.run(
        'sudo', ['bash', '-c', '''
        if [ ! -f /root/.ssh/id_rsa ]; then
          ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
        fi
        '''],
      );

      if (keyGenResult.exitCode == 0) {
        setState(() {
          _output += 'SSH key generated or already exists.\n';
        });
      } else {
        setState(() {
          _output += 'Error generating SSH key: ${keyGenResult.stderr}\n';
        });
        return;
      }

      await _installSshpass();

      for (var ip in _clientIps) {
        final sshResult = await Process.run(
          'sudo', ['bash', '-c', '''
          sshpass -p "root" ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa.pub root@$ip
          '''],
        );

        if (sshResult.exitCode == 0) {
          setState(() {
            _output += 'Passwordless SSH configured for $ip.\n';
          });
        } else {
          setState(() {
            _output += 'Failed to configure SSH for $ip: ${sshResult.stderr}\n';
          });
        }
      }
    } catch (e) {
      setState(() {
        _output += 'Error during SSH setup: $e\n';
      });
    }
  }

  Future<void> _installAnsible() async {
    setState(() {
      _isRunning = true;
      _output += 'Installing Ansible...\n';
    });

    try {
      await _setupPasswordlessSSH();

      await Process.run('sudo', ['apt-get', 'update']);
      await Process.run('sudo', ['apt-get', 'install', '-y', 'ansible']);

      final playbookDir =
          Directory('/home/${_currentUser}/phpcsa/cluster/playbooks');
      if (!await playbookDir.exists()) {
        await playbookDir.create(recursive: true);
      }

      setState(() {
        _output += 'Ansible installed and playbook directory created.\n';
      });
    } catch (e) {
      setState(() {
        _output += 'Error installing Ansible: $e\n';
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

      await _extractClientIps();
    }
  }

  Future<void> _extractClientIps() async {
    if (_inventoryFilePath == null) return;

    try {
      final file = File(_inventoryFilePath!);
      final contents = await file.readAsString();

      final lines = contents.split('\n');
      final ips = <String>[];

      for (var line in lines) {
        final ipPattern = RegExp(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b');
        if (ipPattern.hasMatch(line)) {
          ips.add(ipPattern.firstMatch(line)!.group(0)!);
        }
      }

      setState(() {
        _clientIps = ips;
        _output += 'Client IPs extracted: ${_clientIps.join(', ')}\n';
      });
    } catch (e) {
      setState(() {
        _output += 'Error reading inventory file: $e\n';
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
            if (_clientIps.isNotEmpty)
              Text('Extracted Client IPs: ${_clientIps.join(', ')}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRunning ? null : _installAnsible,
              child: _isRunning
                  ? const CircularProgressIndicator()
                  : const Text('Install Ansible'),
            ),
            const SizedBox(height: 20),
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
