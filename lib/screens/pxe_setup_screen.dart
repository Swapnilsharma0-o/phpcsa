import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:phpcsa/screens/inventory_setup_screen.dart';
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
      await Process.run(
          'sudo', ['ip', 'addr', 'flush', 'dev', _selectedInterface!]);
      await Process.run('sudo', [
        'ip',
        'addr',
        'add',
        '$ipAddress/$subnet',
        'dev',
        _selectedInterface!
      ]);
      await Process.run(
          'sudo', ['ip', 'link', 'set', _selectedInterface!, 'up']);
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

  Future<void> _writeKickstartFile() async {
    const kickstartContent = '''
# create new
install
# automatically proceed for each steps
autostep
# reboot after installing
reboot
# encrypt algorithm
auth --enableshadow --passalgo=sha512
# installation source
url --url=http://192.168.253.60/custom/
# install disk
ignoredisk --only-use=sda
# keyboard layouts
keyboard --vckeymap=jp106 --xlayouts='jp','us'
# system locale
lang en_US.UTF-8
# network settings
network --bootproto=dhcp --ipv6=auto --activate --hostname=localhost
# root password you generated above
rootpw --iscrypted \$6\$8mRjhFsCoiyulUFV\$IlsqapFjs3fsYlWqoJZ1dnkInU4ozoUXNWye2p.XHG71fLOx8S.bpzRKV2rHfEOKugaYDTtf5aXv.lucdzVuE.
# timezone
timezone Asia/Tokyo --isUtc --nontp
# bootloader's settings
bootloader --location=mbr --boot-drive=sda
# initialize all partition tables
zerombr
clearpart --all --initlabel
# partitioning
part /boot --fstype="xfs" --ondisk=sda --size=500
part pv.10 --fstype="lvmpv" --ondisk=sda --size=51200
volgroup VolGroup --pesize=4096 pv.10
logvol / --fstype="xfs" --size=20480 --name=root --vgname=VolGroup
logvol swap --fstype="swap" --size=4096 --name=swap --vgname=VolGroup
%packages
@core
%end
''';

    try {
      final kickstartFile = File('/tmp/kickstart.cfg');
      await kickstartFile.writeAsString(kickstartContent);
      setState(() {
        _output =
            'Kickstart file written successfully to /tmp/kickstart.cfg.\n';
      });
    } catch (e) {
      setState(() {
        _output = 'Error writing Kickstart file: $e';
      });
      _isRunning = false;
      return;
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

    setState(() {
      _isRunning = true;
      _progress = 0.1;
      _output = 'Starting PXE Setup...\n';
    });

    await _writeKickstartFile();

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
sudo apt-get update && sudo apt-get install -y isc-dhcp-server xinetd syslinux-common apache2 pxelinux || error_exit "Package installation failed"
echo "Packages installed."

echo "Copying pxelinux.0..."
sudo rm -f /var/lib/tftpboot/pxelinux.0
sudo cp /usr/lib/PXELINUX/pxelinux.0 /var/lib/tftpboot/ || error_exit "Failed to copy pxelinux.0"
echo "pxelinux.0 copied."

echo "Copying kickstart file..."
mkdir -p /var/www/html/ks
sudo cp /tmp/kickstart.cfg /var/www/html/ks/kickstart.cfg
sudo chmod 644 /var/www/html/ks/kickstart.cfg
echo "Kickstart file copied."

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
    APPEND initrd=custom/images/pxeboot/initrd.img method=http://\$MASTER_IP/custom devfs=nomount ks=http://\$MASTER_IP/ks/kickstart.cfg
" | sudo tee \$TFTP_ROOT/pxelinux.cfg/default > /dev/null
sudo systemctl restart xinetd || error_exit "TFTP server configuration failed"
echo "TFTP server configured."

echo "Mounting ISO and copying files..."
sudo mkdir -p \$ISO_MOUNT_DIR
sudo mount -o loop "\$ISO_FILE" \$ISO_MOUNT_DIR || error_exit "ISO mounting failed"
sudo mkdir -p \$TFTP_ROOT/custom
sudo cp -r \$ISO_MOUNT_DIR/* /var/lib/tftpboot/custom/
sudo mkdir -p \$TFTP_ROOT/custom/images/pxeboot
sudo cp \$ISO_MOUNT_DIR/isolinux/vmlinuz /var/lib/tftpboot/custom/images/pxeboot/
sudo cp \$ISO_MOUNT_DIR/isolinux/initrd.img /var/lib/tftpboot/custom/images/pxeboot/

echo "Files copied."

echo "Copying ISO contents to HTTP directory..."
sudo mkdir -p \$PXE_HTTP_DIR
sudo cp -rT \$ISO_MOUNT_DIR \$PXE_HTTP_DIR || error_exit "Failed to copy ISO contents"
sudo chmod -R 755 \$PXE_HTTP_DIR
sudo mkdir -p \$PXE_HTTP_DIR/pxeboot
sudo cp -rT \$ISO_MOUNT_DIR/isolinux \$PXE_HTTP_DIR/pxeboot
sudo cp -rT \$ISO_MOUNT_DIR/images/pxeboot \$PXE_HTTP_DIR/custom/images/pxeboot
sudo cp /tmp/kickstart.cfg \$PXE_HTTP_DIR/custom/kickstart.cfg
sudo chmod 755 \$PXE_HTTP_DIR/custom/kickstart.cfg
sudo systemctl restart apache2 || error_exit "Apache server restart failed"
echo "ISO contents copied and served via HTTP."

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

# Cleanup
sudo umount \$ISO_MOUNT_DIR

echo "PXE setup complete. Clients can now boot from the network."
''';

    // Write script to a temporary file
    final scriptFile = File('/tmp/pxe_setup.sh');
    await scriptFile.writeAsString(script);

    try {
      // Run the script
      await Process.run('sudo', ['bash', scriptFile.path]);
      setState(() {
        _output += 'PXE setup completed successfully.\n';
        _progress = 1.0;
      });
    } catch (e) {
      setState(() {
        _output += 'Error running PXE setup: $e\n';
      });
    } finally {
      setState(() {
        _isRunning = false;
        _progress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PXE Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Network Interface:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            DropdownButton<String>(
              value: _selectedInterface,
              hint: const Text('Select an interface'),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedInterface = newValue;
                });
              },
              items: _interfaces.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP/Subnet (e.g., 192.168.1.10/24)',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Master IP (for PXE Server)',
              ),
              onChanged: (value) {
                setState(() {
                  _masterIP = value;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickISOFile,
              child: const Text('Pick ISO File'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _assignIP,
              child: const Text('Assign IP'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRunning ? null : _runPXESetup,
              child: _isRunning
                  ? const CircularProgressIndicator()
                  : const Text('Run PXE Setup'),
            ),
            const SizedBox(height: 20),
            if (_isoFilePath != null) Text('Selected ISO File: $_isoFilePath'),
            const SizedBox(height: 20),
            if (_output.isNotEmpty)
              Text(
                'Output:\n$_output',
                style: const TextStyle(color: Colors.green),
              ),
            if (_progress > 0.0) LinearProgressIndicator(value: _progress),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('back'),
                ),
                SizedBox(
                  width: 12,
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const InventorySetupScreen()),
                    );
                  },
                  child: Text('next'),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
