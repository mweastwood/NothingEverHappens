import re

with open('app/lib/screens/task_schedule_screen.dart', 'r') as f:
    content = f.read()

# We want to replace _getRecurrenceRuleDetails and _getMissedPolicyString definitions.
# Wait, let's just delete them entirely and update the call sites.
# Let's find the calls first.
# Call site for _getRecurrenceRuleDetails:
# final parts = _getRecurrenceRuleDetails(context, rule);
content = content.replace("final parts = _getRecurrenceRuleDetails(context, rule);", "final parts = rule.getRecurrenceDetails(context);")

# Call site for _getMissedPolicyString:
# _getMissedPolicyString(context, rule)
content = content.replace("_getMissedPolicyString(context, rule)", "rule.getMissedPolicyDescription(context)")

# Now remove the methods:
# `({String interval, String days, String start}) _getRecurrenceRuleDetails(`
# until `return (interval: intervalStr, days: daysStr, start: startStr);\n  }`
pattern_details = r"\(\{String interval, String days, String start\}\) _getRecurrenceRuleDetails\([\s\S]*?return \(interval: intervalStr, days: daysStr, start: startStr\);\n  \}"
content = re.sub(pattern_details, "", content)

# `String _getMissedPolicyString(`
# until `}\n  }` at the end of the method
pattern_policy = r"String _getMissedPolicyString\([\s\S]*?\}\n  \}"
content = re.sub(pattern_policy, "", content)

with open('app/lib/screens/task_schedule_screen.dart', 'w') as f:
    f.write(content)

print("Screen file updated.")
