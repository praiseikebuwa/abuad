const fs = require('fs');
const file = 'lib/src/features/stories/presentation/create_story_screen.dart';
let c = fs.readFileSync(file, 'utf8');

// 1. In _uploadStory, set caption = textContent for text stories
c = c.replace(/caption = null;\s*backgroundColor = bgColor;/g, 'caption = textContent;\n        backgroundColor = bgColor;');

// 2. Wrap TextField with Theme to eliminate inputDecorationTheme dark box
const oldTextFieldRegex = /child: TextField\(\s*controller: _textController,[\s\S]*?autofocus: true,\s*\),/g;

const newTextField = `child: Theme(
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: const InputDecorationTheme(
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                      ),
                    ),
                    child: TextField(
                      controller: _textController,
                      textAlign: _textAlign,
                      onChanged: (val) {
                        setState(() {});
                      },
                      style: TextStyle(
                        color: _textColor,
                        fontSize: _fontSize,
                        fontWeight: FontWeight.bold,
                        fontFamily: _fontFamily,
                        shadows: _hasShadow
                            ? [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      maxLines: null,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Type a status...',
                        hintStyle: TextStyle(
                          color: _textColor.withValues(alpha: 0.55),
                          fontSize: _fontSize,
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w600,
                        ),
                        filled: _hasTextBackground,
                        fillColor: _hasTextBackground
                            ? Colors.black.withValues(alpha: 0.55)
                            : Colors.transparent,
                        border: _hasTextBackground
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              )
                            : InputBorder.none,
                        enabledBorder: _hasTextBackground
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              )
                            : InputBorder.none,
                        focusedBorder: _hasTextBackground
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              )
                            : InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: _hasTextBackground
                            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
                            : EdgeInsets.zero,
                      ),
                      autofocus: true,
                    ),
                  ),`;

if (!oldTextFieldRegex.test(c)) {
  console.error('Could not match old TextField in create_story_screen.dart');
  process.exit(1);
}
c = c.replace(oldTextFieldRegex, newTextField);

fs.writeFileSync(file, c, 'utf8');
console.log('Successfully patched create_story_screen.dart');
