import re
content = open('lib/screens/individual_chat_screen.dart', 'r', encoding='utf-8').read()
content = re.sub(r'//.*', '', content)
content = re.sub(r"'.*?'", "''", content)
content = re.sub(r'".*?"', '""', content)
lines = content.split('\n')
depth = 0
for i, line in enumerate(lines):
    depth += line.count('{')
    depth -= line.count('}')
    if depth == 0 and i > 70:
        print('Class closed at line:', i + 1)
        break
