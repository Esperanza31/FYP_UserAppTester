import 'package:flutter/material.dart';
import 'package:mini_project_five/pages/busdata.dart';
import 'package:mini_project_five/pages/loading.dart';
import 'package:mini_project_five/pages/map_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BusInfo().loadData();
  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        initialRoute: '/home',
        routes: {
          '/': (context) => Loading(),
          '/home': (context) => Map_Page(),
        }
    );
  }
}