# OMNI — DWG revision management from AutoCAD

AutoLISP commands to snapshot and compare drawing revisions right inside
AutoCAD. Each snapshot is a full copy of the DWG into `_OMNI_HISTORY`
next to the file. Compare = overlay the old revision (XREF + grayscale).

## Install

`APPLOAD` → `OMNI.lsp` (UTF-8, AutoCAD 2015+) or `OMNI_cp1251.lsp` (AutoCAD 2014).

## Commands

| Command | Purpose |
|---|---|
| `OMNI-SNAP` | snapshot DWG copy with timestamp/user/description |
| `OMNI-LOG` | list snapshots, open one |
| `OMNI-DIFF` | overlay a revision as XREF (decolored) |
| `OMNI-CLEAR` | remove only OMNI's own XREFs |
| `OMNI-TOGGLE` | show/hide overlay layers (`name\|*`) |
| `OMNI-NOTE` | circle comment on layer `OMNI_NOTES` |

## v0.4 fixes

- `OMNI-TOGGLE` toggles real XREF layers (`name|*`) instead of a non-existent layer;
- `OMNI-CLEAR` removes only own XREFs;
- `OMNI-SNAP`: milliseconds in the name (no collisions), returns full path.

> C# port (revision diff reports): https://github.com/kostyk348/autocad-electrical-plugin

## License

Internal tool. Use by agreement.
