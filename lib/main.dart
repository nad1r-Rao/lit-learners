import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.useFirebase) {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }
  // Channels and the timezone database have to exist before any reminder can
  // be scheduled, and scheduling happens as soon as a parent opens the list.
  await localNotificationService.initialize();
  runApp(const LittleLearnersApp());
}
