const fs = require('fs');
const file = 'lib/src/features/stories/presentation/my_story_screen.dart';
let c = fs.readFileSync(file, 'utf8');

c = c.replace(/story\.caption \?\? 'Text',/g, "(story.content.isNotEmpty ? story.content : (story.caption ?? 'Text')),");

const oldSubtitleBlock = `if (story.caption != null && story.caption!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                story.caption!,`;

const newSubtitleBlock = `final displayCaption = (story.caption != null && story.caption!.isNotEmpty)
                                  ? story.caption!
                                  : story.content;
                            if (displayCaption.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                displayCaption,`;

c = c.replace(oldSubtitleBlock, newSubtitleBlock);

fs.writeFileSync(file, c, 'utf8');
console.log('Successfully patched my_story_screen.dart');
