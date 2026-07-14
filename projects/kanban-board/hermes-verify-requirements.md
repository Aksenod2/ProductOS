#!/usr/bin/env python3
"""Ad-hoc structural verification of requirements.md for Kanban Board."""

import re
import sys
from pathlib import Path

FILE = Path("/Users/denis/Desktop/vault/projects/ProductOS/projects/kanban-board/requirements.md")
errors = []
warnings = []

content = FILE.read_text(encoding="utf-8")
lines = content.splitlines()

print(f"=== Verification: {FILE.name} ===")
print(f"Size: {FILE.stat().st_size} bytes, {len(lines)} lines\n")

# 1. Required sections
required_sections = [
    "## Цель",
    "## Пользователь",
    "## Функциональные требования",
    "## Нефункциональные требования",
    "## Пользовательские сценарии",
    "## Ограничения",
]

title_check = re.search(r"^#\s+Requirements:\s+Kanban Board", content, re.MULTILINE)
if not title_check:
    errors.append("Missing or incorrect title '# Requirements: Kanban Board'")
else:
    print("✓ Title present")

for section in required_sections:
    if section in content:
        print(f"✓ Section found: {section}")
    else:
        errors.append(f"Missing required section: {section}")

# 2. Functional requirements
func_section = re.search(r"## Функциональные требования.*?(?=##|$)", content, re.DOTALL)
if func_section:
    func_text = func_section.group(0)
    numbered = re.findall(r"^\d+\.\s+", func_text, re.MULTILINE)
    print(f"\n✓ Functional requirements: {len(numbered)} items")
    if len(numbered) < 5:
        errors.append(f"Only {len(numbered)} functional requirements (expected >= 5)")
else:
    errors.append("Could not find functional requirements section")

# 3. Non-functional requirements
nf_section = re.search(r"## Нефункциональные требования.*?(?=##|$)", content, re.DOTALL)
if nf_section:
    nf_text = nf_section.group(0)
    numbered = re.findall(r"^\d+\.\s+", nf_text, re.MULTILINE)
    print(f"✓ Non-functional requirements: {len(numbered)} items")
    if len(numbered) < 5:
        errors.append(f"Only {len(numbered)} non-functional requirements (expected >= 5)")
else:
    errors.append("Could not find non-functional requirements section")

# 4. User stories
stories = re.findall(r"### US-\d+:.*$", content, re.MULTILINE)
print(f"\n✓ User stories: {len(stories)}")

for i, story in enumerate(stories, 1):
    story_start = content.find(story)
    next_story = re.search(rf"### US-{i+1}:.*", content[story_start+len(story):])
    end = story_start + len(story) + next_story.start() if next_story else story_start + len(story) + 1000
    story_text = content[story_start:end]
    ac_count = len(re.findall(r"AC\d+:", story_text))
    if ac_count < 3:
        warnings.append(f"{story.strip()} has only {ac_count} ACs (expected >= 3)")
    else:
        print(f"  ✓ {story.strip()} — {ac_count} ACs")

# 5. Limitations
lim_section = re.search(r"## Ограничения.*$", content, re.DOTALL)
if lim_section:
    lim_text = lim_section.group(0)
    numbered = re.findall(r"^\d+\.\s+", lim_text, re.MULTILINE)
    print(f"\n✓ Limitations: {len(numbered)} items")
    if len(numbered) < 3:
        errors.append(f"Only {len(numbered)} limitations (expected >= 3)")
else:
    errors.append("Could not find limitations section")

# 6. Keywords
keywords = ["localStorage", "drag-and-drop", "one html", "offline", "responsive"]
for kw in keywords:
    if kw.lower() in content.lower():
        print(f"✓ Keyword: '{kw}'")
    else:
        warnings.append(f"Keyword '{kw}' not found")

# 7. User story format check
story_blocks = re.split(r"### US-\d+:.*", content)[1:]
for i, block in enumerate(story_blocks, 1):
    if "**Как**" in block and "**я хочу**" in block and "**чтобы**" in block:
        print(f"\n✓ US-{i} has proper user story format")
    else:
        errors.append(f"US-{i} missing proper user story format")

# Summary
print(f"\n{'='*50}")
if errors:
    print(f"ERRORS ({len(errors)}):")
    for e in errors:
        print(f"  ✗ {e}")
else:
    print("No errors found.")

if warnings:
    print(f"\nWARNINGS ({len(warnings)}):")
    for w in warnings:
        print(f"  ⚠ {w}")
else:
    print("No warnings.")

if not errors:
    print("\n✓✓✓ ALL CHECKS PASSED ✓✓✓")
    sys.exit(0)
else:
    print("\n✗✗✗ SOME CHECKS FAILED ✗✗✗")
    sys.exit(1)
