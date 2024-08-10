import 'package:flutter/material.dart';

class NodeDiscoveryInput extends StatefulWidget {
  const NodeDiscoveryInput({super.key});

  @override
  State<StatefulWidget> createState() => _NodeDicoveryInput();
}

class _NodeDicoveryInput extends State<NodeDiscoveryInput>
    with SingleTickerProviderStateMixin {
  late TabController _controller;
  final _maclistinput = TextEditingController();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Image.asset(
              'lib/assets/img/tp2.png',
              width: 600,
            ),
            const SizedBox(
              height: 6,
            ),
            ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("back")),
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
            // Card(
            //   margin: const EdgeInsets.fromLTRB(400, 0, 400, 0),
            //   child: Padding(
            //     padding: const EdgeInsets.all(8.0),
            //     child: Column(
            //       children: [
            //         TabBar(
            //           controller: _controller,
            //           tabs: [
            //             Tab(
            //               icon: Icon(Icons.person),
            //               text: "manual",
            //             ),
            //             Tab(
            //               icon: Icon(Icons.dynamic_feed),
            //               text: "dynamic",
            //             ),
            //           ],
            //         ),
            //         TabBarView(
            //           controller: _controller,
            //           children: [
            //             Column(
            //               children: <Widget>[
            // //                 const Text(
            // //                   "Enter Mac address",
            // //                   textAlign: TextAlign.left,
            // //                 ),
            // //                 const SizedBox(
            // //                   height: 12,
            // //                 ),
            // //                 TextField(
            // //                   decoration: const InputDecoration(
            // //                     hintText: "Cluster",
            // //                     fillColor: Colors.white10,
            // //                     filled: true,
            // //                   ),
            // //                   controller: _maclistinput,
            // //                   keyboardType: TextInputType.multiline,
            // //                   minLines: 1,
            // //                   maxLines: 10,
            // //                 ),
            // //                 const SizedBox(
            // //                   height: 12,
            // //                 ),
            // //               ],
            //             )
            //           ],
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
