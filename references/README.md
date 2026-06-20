# Reference Source Inventory

This public tree keeps bibliography metadata and source-provenance rows, not
third-party full-text files.

- `references.bib` is the BibLaTeX bibliography used by the report.
- `source-inventory.tsv` records the report role, citation key, and private
  archive path hint for each source considered during the project.
- Paths ending in `.pdf`, `.html`, or `.htm` are intentionally ignored in public
  Git releases. Recreate them from institutional access, publisher pages, DOI
  links, or the project owner's private archive when a local full-text mirror is
  needed for review.

Run `python3 tools/python/scripts/audit_references.py` after editing bibliography metadata
or source-inventory rows.
