import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:process_run/process_run.dart';

class PXESetupScreen extends StatefulWidget {
  const PXESetupScreen({Key? key}) : super(key: key);

  @override
  _PXESetupScreenState createState() => _PXESetupScreenState();
}

class _PXESetupScreenState extends State<PXESetupScreen> {
  String? _selectedInterface;
  String? _masterIP;
  String? _isoFilePath;
  String _output = '';
  double _progress = 0.0;
  bool _isRunning = false;
  List<String> _interfaces = [];
  List<String> _provisionedNodes = [];
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInterfaces();
  }

  Future<void> _fetchInterfaces() async {
    final shell = Shell();
    try {
      final result = await shell.run('ip -br link show');
      final interfaces = result.outText
          .split('\n')
          .where((line) => line.isNotEmpty)
          .map((line) => line.split(' ')[0])
          .toList();

      setState(() {
        _interfaces = interfaces;
      });
    } catch (e) {
      setState(() {
        _output = 'Error fetching interfaces: $e';
      });
    }
  }

  Future<void> _pickISOFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      setState(() {
        _isoFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _assignIP() async {
    if (_selectedInterface == null ||
        _masterIP == null ||
        _ipController.text.isEmpty) {
      setState(() {
        _output =
            'Please select an interface, enter master IP, and specify the IP/subnet.';
      });
      return;
    }

    final ipSubnet = _ipController.text.split('/');
    if (ipSubnet.length != 2) {
      setState(() {
        _output =
            'Invalid IP/Subnet format. Use ip/subnet (e.g., 192.168.1.10/24).';
      });
      return;
    }

    final ipAddress = ipSubnet[0];
    final subnet = ipSubnet[1];

    setState(() {
      _isRunning = true;
      _output = '';
    });

    try {
      await Process.run('sudo',
          ['ip', 'addr', 'flush', 'dev', _selectedInterface.toString()]);
      await Process.run('sudo', [
        'ip',
        'addr',
        'add',
        '$ipAddress/$subnet',
        'dev',
        _selectedInterface.toString()
      ]);
      await Process.run(
          'sudo', ['ip', 'link', 'set', _selectedInterface.toString(), 'up']);
      await Process.run('sudo', ['systemctl', 'restart', 'networking']);

      setState(() {
        _output = 'IP address assigned and network restarted.';
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _output = 'Error assigning IP: $e';
        _isRunning = false;
      });
    }
  }

  Future<void> _writePXEBootConf() async {
    final pxebootConf = '''
Alias /custom /var/pxe/custom
<Directory /var/pxe/custom>
    Options Indexes FollowSymLinks
    Require ip $_masterIP 192.168.253.0/24
</Directory>
''';

    try {
      await Process.run(
        'sudo',
        ['sh', '-c', 'echo "$pxebootConf" > /etc/apache2/pxeboot.conf']
      );
      await Process.run('sudo', ['a2enconf', 'pxeboot']);
      await Process.run('sudo', ['systemctl', 'reload', 'apache2']);
    } catch (e) {
      setState(() {
        _output = 'Error configuring Apache: $e';
      });
    }
  }

  Future<void> _runPXESetup() async {
    if (_selectedInterface == null ||
        _masterIP == null ||
        _isoFilePath == null) {
      setState(() {
        _output =
            'Please select an interface, enter master IP, and pick an ISO file.';
      });
      return;
    }

    final initialDirectory = Directory.current.path;

    setState(() {
      _isRunning = true;
      _progress = 0.1;
      _output = 'Starting PXE Setup...\n';
    });

    final script = '''
#!/bin/bash

MASTER_IP="$_masterIP"
TFTP_ROOT="/var/lib/tftpboot"
ISO_MOUNT_DIR="/mnt/iso"
ISO_FILE="$_isoFilePath"
ROOT_PASSWORD="root"
HTTP_ROOT="/var/www/html"
PXE_HTTP_DIR="/var/pxe/custom"
INTERFACE="$_selectedInterface"
HOSTS_FILE="/etc/hosts"

error_exit() {
    echo "\$1" >&2
    exit 1
}

# Update DHCP configuration
echo "INTERFACESv4=\"\$INTERFACE\"" | sudo tee /etc/default/isc-dhcp-server > /dev/null

echo "Updating package list and installing necessary packages..."
sudo apt-get update && sudo apt-get install -y isc-dhcp-server xinetd syslinux-common apache2 pxelinux|| error_exit "Package installation failed"
echo "Packages installed."

echo "Copying pxelinux.0..."
sudo cp /usr/lib/PXELINUX/pxelinux.0 /var/lib/tftpboot/ || error_exit "Failed to copy pxelinux.0"
echo "pxelinux.0 copied."

echo "Configuring DHCP server..."
echo "subnet 192.168.253.0 netmask 255.255.255.0 {
    range 192.168.253.61 192.168.253.254;
    option domain-name-servers \$MASTER_IP;
    option routers \$MASTER_IP;
    next-server \$MASTER_IP;
    filename \\"pxelinux.0\\";
    default-lease-time 600;
    max-lease-time 7200;
}" | sudo tee /etc/dhcp/dhcpd.conf > /dev/null
sudo systemctl restart isc-dhcp-server || error_exit "DHCP configuration failed"
echo "DHCP server configured."

echo "Configuring TFTP server..."
echo "service tftp
{
    socket_type     = dgram
    protocol        = udp
    wait            = yes
    user            = nobody
    server          = /usr/sbin/in.tftpd
    server_args     = -s \$TFTP_ROOT
    log_on_failure  += USERID
    disable         = no
}" | sudo tee /etc/xinetd.d/tftp > /dev/null
sudo mkdir -p \$TFTP_ROOT
sudo chmod 777 \$TFTP_ROOT
sudo cp /usr/lib/syslinux/modules/bios/*.c32 \$TFTP_ROOT/
PXELINUX_PATH=\$(find /usr -name pxelinux.0 | head -n 1)
sudo ln -sf \$PXELINUX_PATH \$TFTP_ROOT/pxelinux.0
sudo mkdir -p \$TFTP_ROOT/pxelinux.cfg
echo "DEFAULT menu.c32
PROMPT 0   
TIMEOUT 50

MENU TITLE PXE Boot Menu
LABEL Install Custom ISO
    MENU LABEL ^Install Custom ISO
    KERNEL /custom/images/pxeboot/vmlinuz
    APPEND initrd=custom/images/pxeboot/initrd.img method=http://\$MASTER_IP/custom devfs=nomount
" | sudo tee \$TFTP_ROOT/pxelinux.cfg/default > /dev/null
sudo systemctl restart xinetd || error_exit "TFTP configuration failed"
echo "TFTP server configured."

echo "Mounting ISO and copying files..."
sudo mkdir -p \$ISO_MOUNT_DIR
sudo mount -o loop "\$ISO_FILE" \$ISO_MOUNT_DIR || error_exit "ISO mounting failed"
sudo mkdir -p \$PXE_HTTP_DIR
sudo cp -r \$ISO_MOUNT_DIR/* \$PXE_HTTP_DIR/
sudo mkdir -p \$TFTP_ROOT/custom/images/pxeboot
sudo cp \$ISO_MOUNT_DIR/isolinux/vmlinuz \$TFTP_ROOT/custom/images/pxeboot/
sudo cp \$ISO_MOUNT_DIR/isolinux/initrd.img \$TFTP_ROOT/custom/images/pxeboot/
sudo umount \$ISO_MOUNT_DIR || error_exit "ISO unmounting failed"
echo "Files copied."

echo "Configuring Apache..."
echo "Alias /custom \$PXE_HTTP_DIR
<Directory \$PXE_HTTP_DIR>
    Options Indexes FollowSymLinks
    Require ip \$MASTER_IP 192.168.253.0/24
</Directory>" | sudo tee /etc/apache2/pxeboot.conf > /dev/null
sudo a2enconf pxeboot
sudo systemctl reload apache2 || error_exit "Apache configuration failed"
echo "Apache configured."

echo "Setting root password..."
echo "root:\$ROOT_PASSWORD" | sudo chpasswd || error_exit "Setting root password failed"
echo "Root password set."

echo "Updating /etc/hosts with provisioned nodes..."
echo "\$MASTER_IP    pxe-master" | sudo tee -a \$HOSTS_FILE > /dev/null

echo "PXE provisioning setup is complete."
''';

    try {
      // Change to the root directory
      Directory.current = Directory('/');

      final result = await Process.run(
        'bash',
        ['-c', script],
      );

      // Process output
      setState(() {
        _output = result.stdout;
        if (result.stderr.isNotEmpty) {
          _output += '\nError: ${result.stderr}';
        }
        _progress = 1.0;
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _output = 'Error running PXE setup: $e';
        _progress = 0.0;
        _isRunning = false;
      });
    } finally {
      // Restore the initial directory
      Directory.current = Directory(initialDirectory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PXE Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              decoration:
                  const InputDecoration(labelText: 'Select Network Interface'),
              items: _interfaces.map((String interface) {
                return DropdownMenuItem<String>(
                  value: interface,
                  child: Text(interface),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedInterface = newValue;
                });
              },
              value: _selectedInterface,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Enter Master IP'),
              onChanged: (value) {
                setState(() {
                  _masterIP = value;
                });
              },
            ),
            TextFormField(
              controller: _ipController,
              decoration: const InputDecoration(
                  labelText: 'Enter IP/Subnet (e.g., 192.168.1.10/24)'),
            ),
            ElevatedButton(
              onPressed: _assignIP,
              child: const Text('Assign IP to Interface'),
            ),
            ElevatedButton(
              onPressed: _pickISOFile,
              child: const Text('Pick ISO File'),
            ),
            if (_isoFilePath != null) Text('Selected ISO: $_isoFilePath'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRunning ? null : _runPXESetup,
              child: const Text('Run PXE Setup'),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_output),
              ),
            ),
            if (_provisionedNodes.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Provisioned Nodes:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ..._provisionedNodes.map((node) => Text(node)).toList(),
            ],
          ],
        ),
      ),
    );
  }
}
