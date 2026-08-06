import sys

with open('app/test/logic/scheduler_engine_test.dart', 'r') as f:
    content = f.read()

with open('replacement.dart', 'r') as f:
    replacement = f.read()

group_content = f"  group('Missed Occurrence Policies Strategy Unit Tests', () {{\n{replacement}  }});\n"

insert_pos = content.rfind('  });\n}')
if insert_pos != -1:
    new_content = content[:insert_pos] + group_content + content[insert_pos:]
    with open('app/test/logic/scheduler_engine_test.dart', 'w') as f:
        f.write(new_content)
else:
    print("Could not find insertion point.")
