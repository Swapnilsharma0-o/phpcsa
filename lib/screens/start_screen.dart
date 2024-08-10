import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phpcsa/screens/cluster_info_input.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Timer(
      const Duration(seconds: 5),
      () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const ClusterInfoInput(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'lib/assets/img/tp1.png',
              width: 500,
            ),
            const SizedBox(
              height: 6,
            ),
            const Text(
              textAlign: TextAlign.center,
              'PHPCSA',
              style: TextStyle(fontWeight: FontWeight.w800,fontSize: 38),
            ),
          ],
        ),
      ),
    );
  }
}
