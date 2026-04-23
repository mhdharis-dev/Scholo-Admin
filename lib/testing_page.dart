import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExamplePage extends ConsumerStatefulWidget {
  const ExamplePage({super.key});

  @override
  ConsumerState<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends ConsumerState<ExamplePage> {
  @override
  Widget build(BuildContext context) {
    // Example: Watching a provider
    // final data = ref.watch(exampleProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            const SizedBox(height: 40),

            const TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: "Pending Fee", icon: Icon(CupertinoIcons.clock)),
                  Tab(text: "completedFees", icon: Icon(Icons.verified)),
                ]
            ),

            Expanded(
              child: TabBarView(
                children: [
                  Center(child: Text("Ongoing Tasks")),
                  Center(child: Text("Completed Tasks")),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
