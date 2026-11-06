const fs = require('fs');
const file = 'lib/src/features/stories/domain/story.dart';
let c = fs.readFileSync(file, 'utf8');

// 1. In parseColor: replace 'if (raw is int) return raw;' with 'if (raw is num) return raw.toInt();'
c = c.replace(/if \(raw is int\) return raw;/g, 'if (raw is num) return raw.toInt();');

// 2. In toMap: ensure both snake_case and camelCase are present
const oldToMapKeys = `'background_color': backgroundColor,
      'text_color': textColor,
      'font_family': fontFamily,
      'text_align': textAlign,`;

const newToMapKeys = `'background_color': backgroundColor,
      'text_color': textColor,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'font_family': fontFamily,
      'fontFamily': fontFamily,
      'text_align': textAlign,
      'textAlign': textAlign,`;

if (c.includes(oldToMapKeys)) {
  c = c.replace(oldToMapKeys, newToMapKeys);
}

fs.writeFileSync(file, c, 'utf8');
console.log('Successfully updated story.dart');
