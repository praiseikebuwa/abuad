const fs = require('fs');
const file = 'lib/src/features/feed/domain/post.dart';
let c = fs.readFileSync(file, 'utf8');

c = c.replace(/final List<String> mediaUrls;/g, 'final List<String> mediaUrls;\n  final bool isOwner;');
c = c.replace(/this\.isAnonymous = false,/g, 'this.isAnonymous = false,\n    this.isOwner = false,');
c = c.replace(/'is_anonymous': isAnonymous,/g, "'is_anonymous': isAnonymous,\n      'is_owner': isOwner,\n      'isOwner': isOwner,");
c = c.replace(/isAnonymous: map\['is_anonymous'\] \?\? map\['isAnonymous'\] \?\? false,/g, "isAnonymous: map['is_anonymous'] ?? map['isAnonymous'] ?? false,\n      isOwner: map['is_owner'] ?? map['isOwner'] ?? false,");
c = c.replace(/bool\? isAnonymous,/g, 'bool? isAnonymous,\n    bool? isOwner,');
c = c.replace(/isAnonymous: isAnonymous \?\? this\.isAnonymous,/g, 'isAnonymous: isAnonymous ?? this.isAnonymous,\n      isOwner: isOwner ?? this.isOwner,');

fs.writeFileSync(file, c, 'utf8');
console.log('Successfully updated post.dart');
