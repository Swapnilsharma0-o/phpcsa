import 'dart:io';

import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';
import 'package:yaru/yaru.dart';

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  final _form = GlobalKey<FormState>();
  var _clusterName = TextEditingController();
  var _clusterDesc = TextEditingController();
  var _cname;
  var _cdesc;
  var shell = Shell();

  @override
  void initState() {
    Directory.current = '/';

    // TODO: implement initState
    super.initState();

    shell.run('''

# Display some text
echo Hello

pwd

''');
  }

  write() {
    shell.run("mkdir -p /home/ubuntu/Cluster");
    Directory.current = '/home/ubuntu/Cluster';
    // shell.runSync("cd ~/Cluster");
    shell.run("pwd");
    _cname = _clusterName.text;
    _cdesc = _clusterDesc.text;

    Process.run(
      'sh',
      ['-c', 'echo "name: $_cname\ndecription: $_cdesc" > cluster_info.txt'],
    );

    // var process = await Process.start("cat", ['cluster_info.txt']);
    // process.stdin
    //     .writeln('''Hello, world!\n ${_clusterName}\n${_clusterDesc}''');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          // Retrieve the text the that user has entered by using the
          // TextEditingController.
          content: Text(
              '''${_clusterName.text.toString()} and ${_clusterDesc.text.toString()} written to cluster_info'''),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Expanded(
        child: Column(
          children: [
            Image.asset(
              'lib/assets/img/tp3.png',
              width: 600,
            ),
            const SizedBox(
              height: 6,
            ),
            Card(
              margin: EdgeInsets.fromLTRB(400, 0, 400, 0),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      "Enter Cluster Name",
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: "Cluster",
                        fillColor: Colors.white10,
                        filled: true,
                      ),
                      controller: _clusterName,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Text(
                      "Enter Cluster Description",
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: "Description",
                        fillColor: Colors.white10,
                        filled: true,
                      ),
                      controller: _clusterDesc,
                      keyboardType: TextInputType.multiline,
                      minLines: 1, //Normal textInputField will be displayed
                      maxLines: 5,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Container(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          write();
                        },
                        child: const Text("submit"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
