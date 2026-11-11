import sys

tscn_path = r'c:\Users\lipec\Documents\GitHub\TCC\Inventory\fases\sequence_editor.tscn'
with open(tscn_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if line.startswith('[node name="VisualPreviewVBox"'):
        start_idx = i
        break

if start_idx != -1:
    for i in range(start_idx + 1, len(lines)):
        line = lines[i]
        if line.startswith('[connection '):
            end_idx = i
            break
        if line.startswith('[node name=') and 'VisualPreviewVBox' not in line:
            if 'parent=' in line and 'VisualPreviewVBox' not in line:
                end_idx = i
                break

if start_idx != -1 and end_idx != -1:
    vbox_lines = lines[start_idx:end_idx]
    
    # modify parents
    for i in range(len(vbox_lines)):
        if 'parent="Panel/VBoxContainer/HSplitContainer/RightPanel/VBoxContainer/PhaseEditor"' in vbox_lines[i]:
            vbox_lines[i] = vbox_lines[i].replace('PhaseEditor"', 'PhaseEditor/ConfigsVBox"')
        elif 'parent="Panel/VBoxContainer/HSplitContainer/RightPanel/VBoxContainer/PhaseEditor/VisualPreviewVBox' in vbox_lines[i]:
            vbox_lines[i] = vbox_lines[i].replace('PhaseEditor/VisualPreviewVBox', 'PhaseEditor/ConfigsVBox/VisualPreviewVBox')
            
        if 'size_flags_horizontal = 3' in vbox_lines[i] and i > 0 and 'VisualPreviewVBox' in vbox_lines[i-2]:
            vbox_lines.insert(i+1, 'size_flags_vertical = 3\ncustom_minimum_size = Vector2(0, 200)\n')
            
    # remove from original place
    del lines[start_idx:end_idx]
    
    # find HBoxValores
    insert_idx = -1
    for i, line in enumerate(lines):
        if line.startswith('[node name="HBoxValores"'):
            insert_idx = i
            break
            
    if insert_idx != -1:
        lines = lines[:insert_idx] + vbox_lines + ['\n'] + lines[insert_idx:]
        
    with open(tscn_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print('TSCN updated successfully.')
else:
    print('Could not find VisualPreviewVBox bounds.', start_idx, end_idx)
