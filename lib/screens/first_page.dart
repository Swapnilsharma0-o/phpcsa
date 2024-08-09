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
  var shell = Shell();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    shell.run('''

# Display some text
echo Hello

pwd

''');
  }

  void write() {
    shell.run(
        ''' touch /home/ubuntu/Desktop/project/phpcsa-master/cluster_info.txt 
    ${_clusterName.text.toString()} > /home/ubuntu/Desktop/project/phpcsa-master/cluster_info.txt 
    pwd ''');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          // Retrieve the text the that user has entered by using the
          // TextEditingController.
          content: Text('''${_clusterName.text} written to cluster_info'''),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Image.asset(
              'lib/assets/img/tp3.png',
              width: 600,
            ),
            const SizedBox(
              height: 6,
            ),
            const Text(
              textAlign: TextAlign.center,
              'will work here 😅',
            ),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text("Enter Cluster Name"),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: "Cluster",
                          fillColor: Colors.white10,
                          filled: true,
                        ),
                        controller: _clusterName,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        write();
                      },
                      child: const Text("submit"),
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
