import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// A utility to migrate legacy chat channels.
/// It adds 'type': 'direct' to any channel that doesn't have a type.
class ChatMigration {
  static Future<void> migrateChannelTypes() async {
    final firestore = FirebaseFirestore.instance;
    final channels = await firestore.collection('channels').get();

    int migratedCount = 0;
    final batch = firestore.batch();

    for (final doc in channels.docs) {
      final data = doc.data();
      if (!data.containsKey('type')) {
        batch.update(doc.reference, {'type': 'direct'});
        migratedCount++;
      }
    }

    if (migratedCount > 0) {
      await batch.commit();
      debugPrint(
        'Successfully migrated $migratedCount channels to type: direct',
      );
    } else {
      debugPrint('No channels needed migration.');
    }
  }
}
