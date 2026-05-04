# Portfolio — Linux Final Project

A data-processing pipeline built for BYU Stats Class (Introduction to Linux / Data Science).
The project automates the scoring and domain-categorisation of multiple-choice exam responses using Bash, R, and AWK.

---

## Repository Structure

```
portfolio/
└── Linux_Final/
    ├── Data/                        # Raw input files
    │   ├── FormA.csv                # Student answer sheets — Form A
    │   ├── FormB.csv                # Student answer sheets — Form B
    │   ├── Domains_FormA.csv        # Question metadata — Form A
    │   └── Domains_FormB.csv        # Question metadata — Form B
    │
    ├── Final.sh                     # Master pipeline script
    ├── Clean_Final.sh               # Comment-stripped copy of Final.sh
    ├── Init_all.sh                  # MySQL table initialiser (optional DB path)
    ├── Insert_all.sh                # MySQL data loader (optional DB path)
    ├── Get_Dm_nam.sh                # Domain-name consistency validator
    │
    ├── FirstConvert.R               # Scores student answers as 0/1 matrix
    ├── SecondConvert.R              # Helper function used by FirstConvert.R
    ├── WidetoLong.R                 # Reshapes wide matrix to long format
    │
    ├── Numeric.awk                  # Zero-pads student-ID and question-number fields
    ├── Numeric_Domain.awk           # Zero-pads domain question-number field
    │
    ├── scripts/
    │   └── Check_config.sh          # Validates input directory and file existence
    │
    ├── Final_Output                 # Pipeline output (space-delimited, 5 columns)
    └── junk/                        # Intermediate files moved here after each run
```

---

## What the Pipeline Does

1. **Clean up** — removes `Final_Output` and the `junk/` folder so every run starts fresh.
2. **Loop over form files** — iterates over every `Form*.csv` in the supplied input directory.
3. **Separate key from responses** — `grep "KEY"` extracts the answer key; `grep -v "KEY"` extracts student responses.
4. **Score responses** (`FirstConvert.R` + `SecondConvert.R`) — compares each student answer against the key and produces a wide binary matrix (0 = wrong, 1 = correct).
5. **Reshape to long format** (`WidetoLong.R`) — melts the 150-question columns into rows so each record is `(student_id, form, question_number, correct)`.
6. **Clean text** — strips R's default double-quotes with `sed`.
7. **Zero-pad question numbers** (`Numeric.awk`) — formats student IDs and question numbers to three digits (e.g. `7` → `007`) so `join` can do a lexicographic sort-merge.
8. **Process domain file** — strips the header, selects columns 3 and 4 (Domain # and Question #), replaces commas with spaces, and normalises line endings with `dos2unix` (or a `sed` fallback).
9. **Zero-pad domain question numbers** (`Numeric_Domain.awk`) — same zero-padding applied to the domain file's question number field.
10. **Join** — `join -1 3 -2 2` merges the scored responses with domain metadata on the question-number key.
11. **Tidy up** — all intermediate files are moved into `junk/`; `wc Final_Output` confirms the row count.

### Output format

Each row in `Final_Output` contains five space-separated fields:

```
<student_id>  <form>  <question_number>  <domain_number>  <correct>
```

Example:

```
001 A 001 5 0
013 A 001 5 1
```

---

## Input Data Format

### `Form*.csv`
- One row per student (student ID as first field) plus one `KEY` row.
- 151 columns: `student_id`, then one column per question (A/B/C/D), 150 questions total.

### `Domains_Form*.csv`
- Header row followed by 150 item rows.
- Columns: `ItemId`, `Domain` (text), `Domain #` (1–5), `Question #` (1–150).
- Domain categories: Assessment of Performance Needs (1), Program Design and Development (2), Athlete Education and Training (3), Athlete Testing and Evaluation (4), Organisational and Administrat[...]

---

## How to Run

```bash
cd Linux_Final
./Final.sh <input_dir> <file_prefix>
```

| Argument | Description | Example |
|----------|-------------|---------|
| `<input_dir>` | Directory containing `Form*.csv` and `Domains_Form*.csv` | `Data` |
| `<file_prefix>` | Filename prefix to glob on | `Form` |

**Example — local sample data:**

```bash
./Final.sh Data Form
```

**Verify the output:**

```bash
wc Final_Output
# Expected (local 2-form dataset):  3000   15000   42000
# Expected (production 20+ forms):  29850  149250  417900
```

---

## Dependencies

| Dependency | Purpose |
|------------|---------|
| `bash` | Script interpreter |
| `R` / `Rscript` | Answer scoring and wide-to-long reshaping |
| `reshape2` (R package) | `melt()` function — auto-installed if missing |
| `awk` | Leading-zero padding of numeric fields |
| `sed` | Quote removal, header stripping, delimiter replacement |
| `cut` | Column selection from CSV |
| `join` | Sort-merge of scored data with domain metadata |
| `dos2unix` | Windows line-ending removal (optional — `sed` fallback included) |
| `mysql` | Database loading via `Init_all.sh` / `Insert_all.sh` (optional) |

---

## Key Assumptions

- Every form file has **exactly 150 questions**.
- Each `Form*.csv` contains a row whose first field is literally `KEY`.
- Domain files follow the naming convention `Domains_<FormFile>` exactly (e.g. `FormA.csv` pairs with `Domains_FormA.csv`).
- Scripts are executed **from the `Linux_Final/` directory** (relative paths are used throughout).
- The optional `Get_Dm_nam.sh` validator requires a pre-existing `DomMst` master-categories file.
