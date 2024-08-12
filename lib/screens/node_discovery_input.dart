import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yaru_icons/yaru_icons.dart';

class NodeDiscoveryInput extends StatefulWidget {
  const NodeDiscoveryInput({super.key});

  @override
  State<StatefulWidget> createState() => _NodeDicoveryInput();
}

class _NodeDicoveryInput extends State<NodeDiscoveryInput>
    with SingleTickerProviderStateMixin {
//============================================================================================================all variables here please
  late TabController _tabController;
  final _maclistinput = TextEditingController();

  final List<String> _macAddresses = [];
  late Future<List<String>> macAddresses;
  List<String> _interfaces = [];
  String? _selectedInterface;
  final TextEditingController _mac_ip_controller = TextEditingController();

//=============================================================================================fetch interfaces
  Future<List<String>> getNetworkInterfaces() async {
    try {
      print("inside getnetworkinterfaces");
      // Run the 'ip -br addr' command to list network interfaces
      final result = await Process.run('ip', ['-br', 'addr']);
      if (result.exitCode == 0) {
        // Process the output to extract interface names
        final output = result.stdout as String;
        final lines = output.split('\n');
        // Extract the interface name from each line
        return lines
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

//==================================================================load interfaces
  Future<void> _loadNetworkInterfaces() async {
    print("inside load network interface");
    final interfaces = await getNetworkInterfaces();
    setState(() {
      _interfaces = interfaces;
      if (_interfaces.isNotEmpty) {
        _selectedInterface = _interfaces[0];
      }
    });
  }

//==============================================manual mac address
  void _addMacAddress() {
    final macAddress = _mac_ip_controller.text.trim();
    if (macAddress.isNotEmpty && !_macAddresses.contains(macAddress)) {
      setState(() {
        _macAddresses.add(macAddress);
      });
      _mac_ip_controller.clear();
    }
  }

  Future<void> _saveMacAddressesToFile() async {
    final file = File('mac_addresses.txt');
    final content = _macAddresses.join('\n');

    try {
      await file.writeAsString(content);
      await Process.run('cat',
          ['mac_addresses.txt']); // Example command to verify the file contents
      print('MAC addresses saved to mac_addresses.txt');
    } catch (e) {
      print('Error saving MAC addresses: $e');
    }
  }

//=========================================================================dynamic for running a temporary dhcp service to get all the mac addresses
  Future<void> runTemporaryDhcpService() async {
    print("inside temporarydhcp function");
    final configFile = 'dhcpd.conf';
    final logFile = 'dhcp.log';
    final macFile = 'mac_addresses.txt';

    // Create a minimal dhcpd configuration
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

    // Run dhcpd with the configuration on interface ens33
    final process = await Process.start(
      'sudo',
      [
        'dhcpd',
        '-cf',
        configFile,
        '-lf',
        logFile,
        _selectedInterface.toString()
      ],
    );

    // Wait a few seconds to capture DHCP logs
    await Future.delayed(Duration(seconds: 100));

    // Stop dhcpd service
    await Process.run('sudo', ['pkill', 'dhcpd']);
    await Process.run(
      'sh',
      ['-c', 'cat /var/log/syslog | grep -Ei dhcp > dhcp.log'],
    );

    // Extract MAC addresses from the DHCP log
    final logContent = await File(logFile).readAsString();
    final macAddresses = _extractMacAddresses(logContent);

    // Save MAC addresses to a file
    await File(macFile).writeAsString(macAddresses.join('\n'));

    print('MAC addresses saved to $macFile');

    readMacAddresses();
  }

  List<String> _extractMacAddresses(String logContent) {
    final macAddressRegex = RegExp(r'([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}');
    final matches = macAddressRegex.allMatches(logContent);
    return matches.map((match) => match.group(0)!).toSet().toList();
  }

  Future<List<String>> readMacAddresses() async {
    final macFile = 'mac_addresses.txt';
    final file = File(macFile);

    if (await file.exists()) {
      final content = await file.readAsString();
      return content.split('\n').where((line) => line.isNotEmpty).toList();
    } else {
      return [];
    }
    
  }

//===============================================================================================================TODO: implement initState
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNetworkInterfaces();
    macAddresses = readMacAddresses();
  }

//====================================================================================================the main build method handel with care
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // TODO: implement build
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Expanded(
            child: Column(
              children: [
                Image.asset(
                  'lib/assets/img/tp2.png',
                  width: 600,
                ),
                const SizedBox(
                  height: 6,
                ),
                const Text(
                  "Node Discovery",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(
                  height: 6,
                ),
                Center(
                  child: _interfaces.isEmpty
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
                ),
                SizedBox(height: 6),
                Container(
                  width: size.width,
                  height: size.height,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(400, 0, 400, 0),
                    child: Column(
                      children: [
                        TabBar(
                          controller:
                              _tabController, // Provide your TabController here
                          labelColor: Colors.black,
                          tabs: [
                            Tab(
                                icon: Icon(YaruIcons.graphic_tablet),
                                text: 'Manual'),
                            Tab(
                              icon: Icon(YaruIcons.podcast),
                              text: 'Dynamic',
                            ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller:
                                _tabController, // Provide your TabController here as well
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    Text("Enter mac address"),
                                    TextField(
                                      controller: _mac_ip_controller,
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
                                      child: Text('Save'),
                                    ),
                                  ],
                                ),
                              ),
                              Center(
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: ElevatedButton.icon(
                                        onPressed: runTemporaryDhcpService,
                                        label: Text("Discover"),
                                        icon: Icon(YaruIcons.network_wired),
                                      ),
                                    ),
                                    SingleChildScrollView(
                                      child: FutureBuilder<List<String>>(
                                        future: macAddresses,
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return Center(
                                                child:
                                                    CircularProgressIndicator());
                                          } else if (snapshot.hasError) {
                                            return Center(
                                                child: Text(
                                                    'Error: ${snapshot.error}'));
                                          } else if (!snapshot.hasData ||
                                              snapshot.data!.isEmpty) {
                                            return Center(
                                                child: Text(
                                                    'No MAC addresses found.'));
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
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text("Back")),
                            SizedBox(
                              width: 6,
                            ),
                            ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text("Next"))
                          ],
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
