import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Temporary home screen: proves the app can reach Supabase
class ConnectionCheckScreen extends StatefulWidget {
  const ConnectionCheckScreen({super.key, required this.appName});

  final String appName;

  @override
  State<ConnectionCheckScreen> createState() => _ConnectionCheckScreenState();
}

class _ConnectionCheckScreenState extends State<ConnectionCheckScreen> {
  // Ask once when the screen opens, not every time it redraws
  late final Future<List<dynamic>> _pharmacies =
      Supabase.instance.client.from('public_branches').select('id');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.appName)),
      body: Center(
        child: FutureBuilder<List<dynamic>>(
          future: _pharmacies,
          builder: (context, snapshot) {
            // Still loading
            if (snapshot.connectionState != ConnectionState.done) {
              return const CircularProgressIndicator();
            }
            // Couldn't connect
            if (snapshot.hasError) {
              return Text('Could not reach Supabase:\n${snapshot.error}',
                  textAlign: TextAlign.center);
            }
            // Connected
            return Text('Connected · ${snapshot.data!.length} pharmacies');
          },
        ),
      ),
    );
  }
}