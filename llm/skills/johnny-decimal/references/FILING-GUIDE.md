# Filing Guide

Use the JDex flowchart for a detailed filing decision:

```
~/Documents/00-09 System/00 System/00.00 JDex for System/flowchart.md
```

## Quick placement guide

1. **About a specific person?** → `10-19 Personal` under their folder
2. **About yourself specifically?** → `11 Self`
3. **A bill to pay?** → `27 Bills and Reimbursements`
4. **3510 Honeysuckle Way?** → `50-59 3510 Honeysuckle Way`
5. **Other property or vehicle?** → `30-39 Home and Property` (pending rename)
6. **Job/career/education?** → `40-49 Career and Education`
7. **Hobby or creative project?** → `60-69 Hobbies and Recreation`
8. **Litigation or legal proceedings?** → `70-79 Legal and Records`
9. **Household service/utility?** → `80-89 Household and Services`
10. **Reference material?** → `90-99 Reference`

## Common exceptions

- **Personal health records** → Person's folder (e.g., `12.50`)
- **General athletics resources** → `64 Athletics and Activities`
- **House fixtures** (HVAC manual) → With the house in `53 Maintenance and House Systems`
- **Standalone appliances** → `93 Manuals and Documentation`
- **Photos as memories** → `Pictures` folder (outside JD)
- **Photos for projects** → `63 Creative Works`
- **Book cover scans** (for updating ebook covers) → `91.10 Books` under the series folder, not `63 Creative Works`. This is data curation, not an artistic project.

## Choose the filename after inspecting the destination

Before renaming a file for its destination:

1. Run `jd-list.sh <ID> --porcelain` to inspect existing filenames.
2. Match the destination's established pattern. See `NAMING.md` for
   category-specific rules.
3. Keep names short when the directory path already provides the context. Make
   a filename meaningful outside its directory when the category requires it.
   Manuals must identify their brand and product.
4. Treat inbox scan-date filenames, such as `20260127.pdf`, as temporary.
   Inspect the file and rename it to match the destination convention.
