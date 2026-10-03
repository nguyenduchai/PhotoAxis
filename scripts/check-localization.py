#!/usr/bin/env python3
"""Check key parity and all statically referenced app strings."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parent.parent
resources = root / "Sources/PhotoAxisApp/Localization"
keys = {}
for language in ["en", "vi"]:
    path = resources / f"{language}.lproj/Localizable.strings"
    subprocess.run(["plutil", "-lint", str(path)], check=True)
    pairs = re.findall(r'^"([^"\n]+)"\s*=\s*"([^"\n]*)";', path.read_text(), re.M)
    keys[language] = {key for key, value in pairs if value}
    assert len(keys[language]) == len(pairs), f"Duplicate key or empty value: {language}"
assert keys["vi"] == keys["en"], "vi/en key mismatch"
used = set()
for path in (root / "Sources/PhotoAxisApp").rglob("*.swift"):
    source = re.sub(r'identifier\s*=\s*(?:NSUserInterfaceItemIdentifier|\.init)\("[^"]+"\)', '', path.read_text())
    source = source.replace('"document.json"', '')  # ZIP entry name, not a UI key.
    used.update(re.findall(r'\.text\("([^"]+)"\)', source))
    # Keys passed through menu/label helpers and option arrays are literals too.
    used.update(re.findall(r'"((?:recovery|export|project|content|shape|perspective|crop|command|history|transform|document|import|action|color|feature|help|image|language|layer|menu|options|panel|settings|tool|tools|type|view|welcome|workspace)\.[A-Za-z][A-Za-z0-9]*)"', source))
# Channel accessibility names are composed in the Color panel.
used.update("color." + channel for channel in ["R", "G", "B"])
# Tool names are deliberately composed from language-independent enum cases.
tool_source = (root / "Sources/PhotoAxisApp/Tools/ToolKind.swift").read_text()
tool_cases = re.search(r'enum ToolKind[^\{]*\{(.*?)var key', tool_source, re.S)
assert tool_cases, "Cannot validate ToolKind localization keys"
for declaration in re.findall(r'case ([^\n]+)', tool_cases.group(1)):
    used.update("tool." + name.strip() for name in declaration.split(","))
command_source = (root / "Sources/PhotoAxisCore/DocumentModel/DocumentHistory.swift").read_text()
command_cases = re.search(r'enum DocumentCommand[^\{]*\{(.*?)public var', command_source, re.S)
assert command_cases, "Cannot validate DocumentCommand localization keys"
for declaration in re.findall(r'case ([^\n]+)', command_cases.group(1)):
    used.update("command." + name.strip() for name in declaration.split(","))
used.update("perspective." + case for case in ["missingQuad", "invalidQuad", "tooSmall", "invalidOutput", "unstableMapping"])
used.update("transform." + field for field in ["x", "y", "width", "height", "angle"])
used.update("project." + error for error in ["newerVersion", "unsupportedVersion", "resourceLimit", "assetMismatch", "invalid"])
assert used <= keys["en"], f"Missing strings: {used - keys['en']}"
assert len(used) >= 80, "Unexpectedly few localization references; check scanner"
print(f"PASS: {len(keys['en'])} matching vi/en keys; {len(used)} static/dynamic references resolved")
