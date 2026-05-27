import os
import re

# Paths
SUBMODULE_PATH = "protocol-gemini"
HEADER_PATHS = [
    "components/imb_types/include/imb_types.h",
    "components/imb_protocol/include/imb_protocol.h"
]
OUTPUT_PATH = "lib/protocol.dart"

def parse_header(content):
    enums = {}
    structs = {}
    constants = {}

    const_matches = re.findall(r"#define\s+(\w+)\s+([() \w+*-]+)", content)
    for name, val_str in const_matches:
        try:
            clean_val = val_str.strip()
            sorted_keys = sorted(constants.keys(), key=len, reverse=True)
            for c_name in sorted_keys:
                clean_val = clean_val.replace(c_name, str(constants[c_name]))
            constants[name] = eval(clean_val)
        except:
            pass

    content_clean = re.sub(r"/\*.*?\*/", "", content, flags=re.DOTALL)
    content_clean = re.sub(r"//.*", "", content_clean)

    enum_blocks = re.findall(r"typedef enum\s*{(.*?)}\s*(\w+)_e;", content_clean, re.DOTALL)
    for block, name in enum_blocks:
        values = {}
        entries = re.findall(r"(\w+)\s*(?:=\s*(0x[0-9a-f_A-F]+|[0-9_]+))?", block)
        current_val = 0
        for e_name, e_val in entries:
            if not e_name: continue
            if e_val:
                try:
                    values[e_name] = int(e_val.replace('_', ''), 0)
                except ValueError:
                    values[e_name] = current_val
            else:
                values[e_name] = current_val
            current_val = values[e_name] + 1
        enums[name] = values

    struct_blocks = re.findall(r"typedef struct __attribute__\(\(packed\)\)\s*{(.*?)}\s*(\w+)_t;", content_clean, re.DOTALL)
    for block, name in struct_blocks:
        fields = []
        entries = re.findall(r"(\w+)\s+(\w+)(?:\[(\w+)\])?;", block)
        for f_type, f_name, f_size in entries:
            fields.append({
                'type': f_type,
                'name': f_name,
                'size_const': f_size if f_size else None
            })
        structs[name] = fields

    return constants, enums, structs

def generate_dart(constants, enums, structs):
    lines = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND",
        "// Source: components/imb_protocol/include/imb_protocol.h",
        "import 'dart:typed_data';",
        "",
    ]

    for name, val in constants.items():
        lines.append(f"const int {name} = {val};")
    lines.append("")

    for name, values in enums.items():
        lines.append(f"enum {name} {{")
        for e_name, e_val in values.items():
            lines.append(f"  {e_name.lower().replace('imb_', '')}, // {e_val}")
        lines.append("}")
        lines.append("")
        
        lines.append(f"const Map<{name}, int> {name}Values = {{")
        for e_name, e_val in values.items():
            lines.append(f"  {name}.{e_name.lower().replace('imb_', '')}: {e_val},")
        lines.append("};")
        lines.append("")

    for name, fields in structs.items():
        class_name = "".join(x.capitalize() for x in name.replace("imb_pkt_", "").replace("imb_", "").replace("_t", "").split("_"))
        lines.append(f"class {class_name} {{")
        
        valid_fields = []
        for f in fields:
            if f['type'] in ['uint8_t', 'uint16_t', 'uint32_t'] or (f['type'] == 'char' and f['size_const']):
                valid_fields.append(f)

        for f in valid_fields:
            dart_type = "int"
            if f['type'] == 'char' and f['size_const']:
                dart_type = "String"
            lines.append(f"  final {dart_type} {f['name']};")
        
        lines.append("")
        lines.append(f"  {class_name}({{")
        for f in valid_fields:
            lines.append(f"    required this.{f['name']},")
        lines.append("  });")
        lines.append("")

        lines.append(f"  factory {class_name}.fromBytes(Uint8List bytes) {{")
        lines.append("    var offset = 0;")
        lines.append("    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);")
        
        lines.append("    Map<String, dynamic> inits = {};")
        for f in fields:
            if f['type'] == 'uint8_t':
                if f in valid_fields:
                    lines.append(f"    inits['{f['name']}'] = data.getUint8(offset);")
                lines.append("    offset += 1;")
            elif f['type'] == 'uint16_t':
                if f in valid_fields:
                    lines.append(f"    inits['{f['name']}'] = data.getUint16(offset, Endian.little);")
                lines.append("    offset += 2;")
            elif f['type'] == 'uint32_t':
                if f in valid_fields:
                    lines.append(f"    inits['{f['name']}'] = data.getUint32(offset, Endian.little);")
                lines.append("    offset += 4;")
            elif f['type'] == 'char' and f['size_const']:
                size_name = f['size_const']
                if f in valid_fields:
                    lines.append(f"    inits['{f['name']}'] = String.fromCharCodes(bytes.sublist(offset, offset + {size_name})).split('\\x00')[0];")
                lines.append(f"    offset += {size_name};")
            else:
                if f['size_const'] and f['size_const'] in constants:
                    lines.append(f"    offset += {f['size_const']};")
                else:
                    lines.append(f"    // Skip {f['name']}")

        lines.append(f"    return {class_name}(")
        for f in valid_fields:
            lines.append(f"      {f['name']}: inits['{f['name']}'],")
        lines.append("    );")
        lines.append("  }")
        lines.append("")

        lines.append("  Uint8List toBytes() {")
        total_size_parts = []
        for f in fields:
            if f['type'] == 'uint8_t': total_size_parts.append("1")
            elif f['type'] == 'uint16_t': total_size_parts.append("2")
            elif f['type'] == 'uint32_t': total_size_parts.append("4")
            elif f['size_const'] and f['size_const'] in constants: total_size_parts.append(f['size_const'])
            else: total_size_parts.append("0")
        
        lines.append(f"    var bytes = Uint8List({ ' + '.join(total_size_parts) if total_size_parts else '0' });")
        lines.append("    var data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);")
        lines.append("    var offset = 0;")
        
        for f in fields:
            if f in valid_fields:
                if f['type'] == 'uint8_t':
                    lines.append(f"    data.setUint8(offset, {f['name']});")
                    lines.append("    offset += 1;")
                elif f['type'] == 'uint16_t':
                    lines.append(f"    data.setUint16(offset, {f['name']}, Endian.little);")
                    lines.append("    offset += 2;")
                elif f['type'] == 'uint32_t':
                    lines.append(f"    data.setUint32(offset, {f['name']}, Endian.little);")
                    lines.append("    offset += 4;")
                elif f['type'] == 'char' and f['size_const']:
                    size = f['size_const']
                    lines.append(f"    var {f['name']}Bytes = Uint8List.fromList({f['name']}.codeUnits);")
                    lines.append(f"    for (var i = 0; i < {f['name']}Bytes.length && i < {size}; i++) {{")
                    lines.append(f"      bytes[offset + i] = {f['name']}Bytes[i];")
                    lines.append("    }")
                    lines.append(f"    offset += {size};")
            else:
                 if f['type'] == 'uint8_t': lines.append("    offset += 1;")
                 elif f['type'] == 'uint16_t': lines.append("    offset += 2;")
                 elif f['type'] == 'uint32_t': lines.append("    offset += 4;")
                 elif f['size_const'] and f['size_const'] in constants: lines.append(f"    offset += {f['size_const']};")

        lines.append("    return bytes;")
        lines.append("  }")
        
        lines.append("}")
        lines.append("")

    return "\n".join(lines)

def main():
    full_content = ""
    for h in HEADER_PATHS:
        file_path = os.path.join(SUBMODULE_PATH, h)
        if not os.path.exists(file_path):
            print(f"Warning: {file_path} not found")
            continue
        with open(file_path, 'r') as f:
            full_content += f.read() + "\n"
    
    constants, enums, structs = parse_header(full_content)
    dart_code = generate_dart(constants, enums, structs)
    
    with open(OUTPUT_PATH, 'w') as f:
        f.write(dart_code)
    print(f"Generated {OUTPUT_PATH}")

if __name__ == "__main__":
    main()
