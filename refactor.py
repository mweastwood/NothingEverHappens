import re
import sys

def parse_blocks(content):
    idx = 0
    while True:
        match = re.search(r'TaskSchedule\(', content[idx:])
        if not match:
            break
        
        start_idx = idx + match.start()
        
        paren = 0
        end_idx = -1
        for i in range(start_idx, len(content)):
            if content[i] == '(':
                paren += 1
            elif content[i] == ')':
                paren -= 1
                if paren == 0:
                    end_idx = i + 1
                    break
        
        if end_idx == -1:
            idx = start_idx + 1
            continue
            
        block = content[start_idx:end_idx]
        
        new_block = transform_block(block)
        if new_block != block:
            content = content[:start_idx] + new_block + content[end_idx:]
            idx = start_idx + len(new_block)
        else:
            idx = end_idx
            
    return content

def transform_block(block):
    if block.count('Schedule(') != 2: 
        return block
        
    if 'OneOffSchedule(' in block:
        kind = 'OneOff'
    elif 'DailySchedule(' in block:
        kind = 'Daily'
    elif 'WeeklySchedule(' in block:
        kind = 'Weekly'
    else:
        return block
        
    task_fields = extract_fields(block, 'TaskSchedule')
    inner_fields = extract_fields(block, kind + 'Schedule')
    
    if not task_fields or not inner_fields:
        return block
        
    args = []
    
    valid_task_fields = ['id', 'title', 'description', 'priority', 'isFamily', 'isMaster', 'assignedUserId', 'cycleId']
    for k, v in task_fields.items():
        if k in valid_task_fields:
            args.append(f"{k}: {v}")
            
    valid_inner_fields = ['date', 'startDate', 'interval', 'daysOfWeek', 'startRelativeTime', 'dueRelativeTime', 'notificationRelativeTimes', 'schedulingPolicy', 'missedOccurrencePolicy']
    for k, v in inner_fields.items():
        if k in valid_inner_fields:
            args.append(f"{k}: {v}")
            
    args_str = ",\n          ".join(args)
    return f"TestTaskFactory.create{kind}(\n          {args_str},\n        )"

def extract_fields(block, name):
    match = re.search(name + r'\s*\(', block)
    if not match: return {}
    start_idx = match.end() - 1
    
    paren = 0
    end_idx = -1
    for i in range(start_idx, len(block)):
        if block[i] == '(': paren += 1
        elif block[i] == ')':
            paren -= 1
            if paren == 0:
                end_idx = i
                break
                
    inner = block[start_idx+1:end_idx]
    
    fields = {}
    paren = 0
    current_key = None
    current_val = []
    
    i = 0
    while i < len(inner):
        if current_key is None:
            match = re.search(r'^\s*([a-zA-Z0-9_]+)\s*:', inner[i:])
            if match:
                current_key = match.group(1)
                i += match.end()
            else:
                # advance until next comma if garbage
                while i < len(inner) and inner[i] != ',':
                    i += 1
                if i < len(inner) and inner[i] == ',':
                    i += 1
        else:
            c = inner[i]
            if c in '([{<': paren += 1
            elif c in ')]}>': paren -= 1
            
            if c == ',' and paren == 0:
                fields[current_key] = "".join(current_val).strip()
                current_key = None
                current_val = []
            else:
                current_val.append(c)
            i += 1
            
    if current_key is not None:
        fields[current_key] = "".join(current_val).strip()
        
    return fields

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    if "import '../test_factories.dart';" not in content and "TestTaskFactory" not in content:
        content = content.replace("import 'package:flutter_test/flutter_test.dart';", "import 'package:flutter_test/flutter_test.dart';\nimport '../test_factories.dart';")

    new_content = parse_blocks(content)
    
    with open(filepath, 'w') as f:
        f.write(new_content)

if __name__ == '__main__':
    for arg in sys.argv[1:]:
        process_file(arg)
