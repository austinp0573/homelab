Yes. The layout should be:

```text
talos/                           # cloned repository
├── website/
├── _out/
│   └── extract-config-examples.py
└── ...
```

Run **from the repository root**:

```bash
cd talos
python3 _out/extract-config-examples.py
```

It reads:

```text
website/content/v1.15/reference/configuration/
```

And creates:

```text
reference/configuration/
```

populated with the **122 document-level YAML examples**, preserving subdirectories, plus `index.json` mapping them to their sources.

Python 3 is the only dependency. The script is custom and must be copied into the fresh clone; Git will not supply it. `_out/` is simply where we placed it, not a requirement.

To include subsection and field fragments too:

```bash
python3 _out/extract-config-examples.py \
    --all \
    --output reference/configuration-all
```
