import 'dart:io';
import 'package:flutter/material.dart';
import 'package:yaru_icons/yaru_icons.dart';

class NodeDiscoveryInput extends StatefulWidget {
  const NodeDiscoveryInput({Key? key}) : super(key: key);

  @override
  State<NodeDiscoveryInput> createState() => _NodeDiscoveryInputState();
}

class _NodeDiscoveryInputState extends State<NodeDiscoveryInput>
    with SingleTickerProviderStateMixin {
  // Variables
  late TabController _tabController;
  final TextEditingController _macIpController = TextEditingController();
  final List<String> _macAddresses = [];
  late Future<List<String>> _macAddressesFuture;
  List<String> _interfaces = [];
  String? _selectedInterface;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNetworkInterfaces();
    _macAddressesFuture = _readMacAddresses();
  }

  // Fetch network interfaces
  Future<List<String>> _getNetworkInterfaces() async {
    try {
      final result = await Process.run('ip', ['-br', 'addr']);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        return output
            .split('\n')
            .where((line) => line.isNotEmpty)
            .map((line) => line.split(' ').first)
            .toList();
      } else {
        throw Exception('Failed to fetch network interfaces');
      }
    } catch (e) {
      print('Error fetching network interfaces: $e');
      return [];
    }
  }

  // Load network interfaces
  Future<void> _loadNetworkInterfaces() async {
    final interfaces = await _getNetworkInterfaces();
    setState(() {
      _interfaces = interfaces;
      _selectedInterface = interfaces.isNotEmpty ? interfaces[0] : null;
    });
  }

  // Add MAC address
  void _addMacAddress() {
    final macAddress = _macIpController.text.trim();
    if (macAddress.isNotEmpty && !_macAddresses.contains(macAddress)) {
      setState(() {
        _macAddresses.add(macAddress);
        _macIpController.clear();
      });
    }
  }

  // Save MAC addresses to file
  Future<void> _saveMacAddressesToFile() async {
    final file = File('mac_addresses.txt');
    final content = _macAddresses.join('\n');

    try {
      await file.writeAsString(content);
      print('MAC addresses saved to mac_addresses.txt');
    } catch (e) {
      print('Error saving MAC addresses: $e');
    }
  }

  // Run temporary DHCP service
  Future<void> _runTemporaryDhcpService() async {
    print('in temp dhcp service');
    final configFile = 'dhcpd.conf';
    final logFile = 'dhcp.log';
    final macFile = 'mac_addresses.txt';

    final configContent = '''
default-lease-time 600;
max-lease-time 7200;
log-facility local7;

subnet 192.168.253.0 netmask 255.255.255.0 {
  range 192.168.253.2 192.168.253.10;
  option routers 192.168.253.1;
}
''';

    await File(configFile).writeAsString(configContent);

    final process = await Process.start(
      'sudo',
      ['dhcpd', '-cf', configFile, '-lf', logFile, _selectedInterface!],
    );

    await Future.delayed(Duration(seconds: 100));

    await Process.run('sudo', ['pkill', 'dhcpd']);
    await Process.run(
        'sh', ['-c', 'cat /var/log/syslog | grep -Ei dhcp > $logFile']);

    final logContent = await File(logFile).readAsString();
    final macAddresses = _extractMacAddresses(logContent);

    await File(macFile).writeAsString(macAddresses.join('\n'));

    print('MAC addresses saved to $macFile');

    setState(() {
      _macAddressesFuture = _readMacAddresses();
    });
  }

  // Extract MAC addresses from log content
  List<String> _extractMacAddresses(String logContent) {
    final macAddressRegex = RegExp(r'([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}');
    final matches = macAddressRegex.allMatches(logContent);
    return matches.map((match) => match.group(0)!).toSet().toList();
  }

  // Read MAC addresses from file
  Future<List<String>> _readMacAddresses() async {
    final file = File('mac_addresses.txt');
    if (await file.exists()) {
      final content = await file.readAsString();
      return content.split('\n').where((line) => line.isNotEmpty).toList();
    } else {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Image.asset(
                'lib/assets/img/tp2.png',
                width: 600,
              ),
              const SizedBox(height: 6),
              const Text(
                "Node Discovery",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _interfaces.isEmpty
                  ? CircularProgressIndicator()
                  : DropdownButton<String>(
                      value: _selectedInterface,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedInterface = newValue;
                        });
                      },
                      items: _interfaces
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
              SizedBox(height: 6),
              Container(
                width: size.width,
                height: size.height,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.black,
                      tabs: [
                        Tab(
                          icon: Icon(YaruIcons.graphic_tablet),
                          text: 'Manual',
                        ),
                        Tab(
                          icon: Icon(YaruIcons.podcast),
                          text: 'Dynamic',
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildManualTab(),
                          _buildDynamicTab(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Back"),
                        ),
                        SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Next"),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualTab() {
    return Center(
      child: Column(
        children: [
          const Text("Enter MAC address"),
          TextField(
            controller: _macIpController,
            decoration: InputDecoration(
              labelText: 'MAC Address',
              suffixIcon: IconButton(
                icon: Icon(Icons.add),
                onPressed: _addMacAddress,
              ),
            ),
            keyboardType: TextInputType.text,
          ),
          SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _macAddresses.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_macAddresses[index]),
                );
              },
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveMacAddressesToFile,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicTab() {
    return Center(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _runTemporaryDhcpService,
              label: const Text("Discover"),
              icon: Icon(YaruIcons.network_wired),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _macAddressesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No MAC addresses found.'));
                } else {
                  final macList = snapshot.data!;
                  return ListView.builder(
                    itemCount: macList.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(macList[index]),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
