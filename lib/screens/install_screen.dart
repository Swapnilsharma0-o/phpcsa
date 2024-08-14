import 'dart:io';

import 'package:flutter/material.dart';
import 'package:process_run/process_run.dart';

class ServiceInstallScreen extends StatefulWidget {
  const ServiceInstallScreen({Key? key}) : super(key: key);

  @override
  _ServiceInstallScreenState createState() => _ServiceInstallScreenState();
}

class _ServiceInstallScreenState extends State<ServiceInstallScreen> {
  final _formKey = GlobalKey<FormState>();
  final _services = <String, bool>{
    'SLURM': false,
    'Nagios': false,
    'LDAP': false,
    'Ganglia': false,
    'PBS': false,
    'TrueNAS': false,
  };

  Future<void> _installServices() async {
    setState(() {
      // Show a progress indicator or similar
    });

    try {
      for (var entry in _services.entries) {
        if (entry.value) {
          await _installService(entry.key);
        }
      }

      setState(() {
        // Update UI to show installation is complete
      });
    } catch (e) {
      // Handle errors
    }
  }

  Future<void> _installService(String service) async {
    switch (service) {
      case 'SLURM':
        await Process.run('sudo', ['apt-get', 'install', '-y', 'slurm-wlm']);
        break;
      case 'Nagios':
        await Process.run('sudo', ['apt-get', 'install', '-y', 'nagios3']);
        break;
      case 'LDAP':
        await Process.run('sudo', ['apt-get', 'install', '-y', 'slapd', 'ldap-utils']);
        break;
      case 'Ganglia':
        await Process.run('sudo', ['apt-get', 'install', '-y', 'ganglia-monitor', 'ganglia-gmetad']);
        break;
      case 'PBS':
        await Process.run('sudo', ['apt-get', 'install', '-y', 'torque-server', 'torque-client']);
        break;
      case 'TrueNAS':
        // Note: TrueNAS is not a package but a separate operating system. This is just a placeholder.
        await Process.run('echo', ['TrueNAS cannot be installed via apt-get']);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Install Services'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Services to Install:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ..._services.keys.map((service) {
                return CheckboxListTile(
                  title: Text(service),
                  value: _services[service],
                  onChanged: (bool? value) {
                    setState(() {
                      _services[service] = value ?? false;
                    });
                  },
                );
              }).toList(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _installServices,
                child: const Text('Install Selected Services'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
