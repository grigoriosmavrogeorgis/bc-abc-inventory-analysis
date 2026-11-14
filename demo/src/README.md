# ABC Inventory Analysis Demo Data

Object IDs 60000-60099, a block of its own so the app can share a sandbox with other GMSOFT demo apps.
Codeunit 60000 "GSO ABC Demo Data" prepares setup, counting periods and a counting policy, and applies a first Revenue run.
It runs once per company on install (codeunit 60001) and only fills in what is empty.
