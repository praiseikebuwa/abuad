# abuad

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firestore index troubleshooting

If you see a runtime error like:

`[cloud_firestore/failed-precondition] The query requires an index`

use this checklist:

1. Open the URL provided in the error message.
2. Compare the suggested index with `firestore.indexes.json`.
3. If missing, add it to `firestore.indexes.json`.
4. Deploy indexes:

```bash
firebase deploy --only firestore:indexes
```

5. Wait for index build completion in Firestore Console before retesting.

### Chat queries that require composite indexes

Current chat feature uses these index-sensitive queries on `channels`:

1. `where('member_ids', arrayContains: uid).orderBy('last_message_time', descending: true)`
2. `where('type', isEqualTo: 'direct').where('member_ids', arrayContains: uid)`
