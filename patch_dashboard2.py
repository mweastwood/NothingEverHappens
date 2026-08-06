with open('app/lib/screens/dashboard_screen.dart', 'r') as f:
    lines = f.readlines()

out_lines = []
skip = False
for line in lines:
    if line.startswith('class DashedRectPainter extends CustomPainter'):
        skip = True
    if not skip:
        out_lines.append(line)

with open('app/lib/screens/dashboard_screen.dart', 'w') as f:
    f.writelines(out_lines)
