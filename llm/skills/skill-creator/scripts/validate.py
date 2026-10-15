# /// script
# requires-python = ">=3.11"
# dependencies = ["PyYAML==6.0.3"]
# ///
"""Check portable skill metadata; keep authoring advice separate from errors."""

import argparse
from pathlib import Path

import yaml


class UniqueKeyLoader(yaml.SafeLoader):
    """Reject ambiguous duplicate keys, including nested metadata keys."""

    def construct_mapping(self, node, deep=False):
        mapping = {}
        for key_node, value_node in node.value:
            key = self.construct_object(key_node, deep=deep)
            if not isinstance(key, str):
                raise ValueError("YAML mapping keys must be strings")
            if key in mapping:
                raise ValueError(f"duplicate YAML key: {key}")
            mapping[key] = self.construct_object(value_node, deep=deep)
        return mapping


def validate(skill_dir):
    errors = []
    warnings = []
    skill_file = skill_dir / "SKILL.md"
    try:
        text = skill_file.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError) as error:
        return [str(error)], warnings

    lines = text.splitlines()
    if not lines or lines[0].rstrip() != "---":
        return ["SKILL.md must start with YAML frontmatter (---)"], warnings
    try:
        closing = next(
            index for index in range(1, len(lines)) if lines[index].rstrip() == "---"
        )
    except StopIteration:
        return ["YAML frontmatter needs a closing ---"], warnings
    try:
        fields = yaml.load("\n".join(lines[1:closing]), Loader=UniqueKeyLoader)
    except (yaml.YAMLError, ValueError) as error:
        return [f"invalid YAML: {error}"], warnings
    if not isinstance(fields, dict):
        return ["frontmatter must be a mapping"], warnings

    for field, limit in (("name", 64), ("description", 1024), ("compatibility", 500)):
        if field not in fields and field == "compatibility":
            continue
        value = fields.get(field)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{field} must be a nonempty string")
        elif len(value) > limit:
            errors.append(f"{field} exceeds {limit} characters")

    name = fields.get("name")
    if isinstance(name, str):
        # The reference implementation accepts Unicode lowercase letters/digits.
        # Warn for ASCII interoperability rather than rejecting those names.
        if (
            not name
            or not all(
                char == "-" or (char.isalnum() and char == char.lower())
                for char in name
            )
            or name.startswith("-")
            or name.endswith("-")
            or "--" in name
        ):
            errors.append("name must use lowercase alphanumerics and single internal hyphens")
        if name != skill_dir.resolve().name:
            errors.append("name must match the skill directory")
        if not name.isascii():
            warnings.append("prefer ASCII names for interoperability")
        if "claude" in name or "anthropic" in name:
            warnings.append(
                "name contains claude or anthropic; Claude API uploads reject these names"
            )

    description = fields.get("description")
    if isinstance(description, str) and ("<" in description or ">" in description):
        warnings.append(
            "description contains angle brackets; some hosts and upload validators reject them"
        )

    if "license" in fields and not isinstance(fields["license"], str):
        errors.append("license must be a string")
    if "metadata" in fields:
        metadata = fields["metadata"]
        if not isinstance(metadata, dict) or not all(
            isinstance(key, str) and isinstance(value, str)
            for key, value in metadata.items()
        ):
            errors.append("metadata must map string keys to string values")

    portable_fields = {
        "name", "description", "license", "compatibility", "metadata", "allowed-tools"
    }
    for field in fields.keys() - portable_fields:
        warnings.append(f"nonstandard field {field!r}: verify support in each target host")
    if "allowed-tools" in fields:
        warnings.append("allowed-tools is experimental; host enforcement varies")
        if not isinstance(fields["allowed-tools"], str):
            warnings.append(
                "allowed-tools uses a host-specific type; "
                "the spec's portable form is a space-separated string"
            )
    if len(lines) > 500:
        warnings.append(f"SKILL.md has {len(lines)} lines; under 500 is recommended")
    if not any(line.strip() for line in lines[closing + 1:]):
        warnings.append("instruction body is empty")
    scaffold_markers = (
        "TODO — describe what this skill does and when to use it.",
        "TODO: Write skill instructions here.",
    )
    if any(marker in text for marker in scaffold_markers):
        errors.append("replace unfinished scaffold markers")
    return errors, warnings


def main():
    parser = argparse.ArgumentParser(
        description="Validate shared Agent Skills metadata, not host extensions or behavior. "
        "Exit 1 on invalid metadata or unfinished scaffold markers; warnings do not fail."
    )
    parser.add_argument("skill_directory", type=Path)
    arguments = parser.parse_args()
    errors, warnings = validate(arguments.skill_directory)
    for warning in sorted(warnings):
        print(f"WARN  {warning}")
    for error in errors:
        print(f"FAIL  {error}")
    if errors:
        print(f"{len(errors)} check(s) failed.")
        return 1
    print("PASS  portable metadata checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
