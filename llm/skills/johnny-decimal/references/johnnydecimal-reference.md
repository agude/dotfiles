# Johnny.Decimal Reference

Use this file for general Johnny.Decimal concepts. It describes the vocabulary
and structure; it does not override the user's local filing policy in
`jdex.md`.

## Structure

```text
XX-XX Area Name/
└── XX Category Name/
    └── XX.YY ID Name/
```

- An area is a ten-number range, such as `20-29`.
- A category is the two-digit number before the decimal, such as `21`.
- An ID is the two-part number that identifies a specific item, such as
  `21.10`.
- The ID is the stable reference. The name can describe what the ID means.
- System-management locations commonly use the `.00` through `.09` range.

Numbers are shorthand for locations and concepts. They can identify a folder,
a note, an email, an account, a physical record, or another external location.
The filesystem is only one component of a Johnny.Decimal system.

## Core principles

- Give each item one clear home.
- Use purpose to decide where an item belongs.
- Keep the index searchable and use it to record where related information
  lives.
- Use notes for context that does not belong in the document itself.
- Prefer a simple two-dimensional structure. Add extra notation or systems
  only when the existing structure cannot express the relationship clearly.

## Notation boundaries

The local system currently uses one personal system and ordinary filesystem
folders. Do not invent system prefixes or expansion syntax while filing. Use
additional Johnny.Decimal notation only when the user has explicitly adopted
it for the item or system.

## Source of truth

This is a local reference snapshot. For the user's actual areas, categories,
IDs, exceptions, and placement rules, use the local JDex policy and its
`overview.md` and `flowchart.md` files.
