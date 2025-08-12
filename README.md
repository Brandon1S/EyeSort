## EyeSort: Region-aware eye-tracking event labeling for EEGLAB

EyeSort is an EEGLAB plugin that integrates text/pixel interest areas with synchronized eye-tracking events and builds robust, reproducible label codes for ERP binning. It adds a guided GUI workflow to:

- Load one or many EEG `.set` datasets
- Define interest areas (text-based sentences or pixel regions)
- Label fixations and saccades with rich criteria (region, pass, fixation type, saccade direction)
- Auto-generate BINLISTER Bin Descriptor Files (BDF) from labeled codes
- Save labeled datasets for downstream ERP workflows

Current version: see `eyesort_default_values.m` (e.g., `0.4.7`).

### Requirements

- **MATLAB** and **EEGLAB** installed (EyeSort is an EEGLAB plugin)
- Datasets must already be synchronized with eye-tracking events (e.g., via the EYE-EEG pipeline) so that fixation and saccade events exist in `EEG.event`
  - Defaults assume: `R_fixation`, `R_saccade`, `fix_avgpos_x`, `sac_startpos_x`, `sac_endpos_x` (all customizable in the GUI)

### Installation

1) Copy the `EyeSort` folder into your EEGLAB `plugins/` directory.
2) Launch EEGLAB in MATLAB. EyeSort auto-adds its subfolders to the MATLAB path.
3) Verify the `EyeSort` menu appears in EEGLAB’s toolbar. If multiple EyeSort copies are detected, the first found on path is used.

### Data prerequisites

- EEG datasets must contain synchronized eye-tracking events (fixations/saccades) in `EEG.event`.
- For text-based interest areas you need a tab-delimited file with one row per stimulus (trial) containing:
  - A condition trigger code column (e.g., `trigcondition`)
  - An item trigger code column (e.g., `trigitem`)
  - One column per region with the literal text shown on screen (region names are user-specified in the GUI)

### End-to-end workflow (GUI)

The EEGLAB menu sequence under `EyeSort` guides you through the pipeline.

#### 1) Load EEG Dataset(s)

Use `EyeSort → 1. Load EEG Dataset(s)` (`pop_load_datasets`):

- Single dataset: select one `.set` file; it is loaded into `EEG`/`ALLEEG`.
- Batch mode: select an input directory of `.set` files and an output directory. EyeSort validates file existence, records paths in the base workspace, and loads the first dataset for display. Processing is done one-at-a-time to avoid memory issues.

Outputs and state:
- Single dataset mode: datasets are loaded into EEGLAB immediately.
- Batch mode: defines `eyesort_batch_*` variables (file paths, filenames, output dir, mode flag) used by later steps.

#### 2) Setup Interest Areas

Use `EyeSort → 2. Setup Interest Areas → Text-Based Sentence Contents and Interest Areas` (`pop_load_text_ia`). This step:

- Reads your tab-delimited IA file and extracts per-trial region boundaries and words
- Maps those boundaries to events using your trial start/end triggers and item/condition triggers
- Derives trial/region metadata for downstream labeling and BDF generation

Key inputs in the GUI (with defaults/placeholders):
- Sentence offset in pixels (e.g., 281)
- Pixels per character (e.g., 14)
- Number of regions and region names (comma-separated; order matters)
- Condition label column name(s) for BDF descriptions (can be multiple, comma-separated)
- Condition trigger code column (e.g., `trigcondition`) and item trigger code column (e.g., `trigitem`)
- Trial start/end codes (e.g., `S254`, `S255`)
- Optional eye-event time window codes (stimulus start/end; e.g., `S250`, `S251`)
- Condition triggers (comma-separated; e.g., `S211, S213, S221, S223`)
- Item triggers (supports ranges; e.g., `S1:S112`)
- Eye event names/fields (fixation, saccade, X positions) — customizable if your dataset differs from defaults

Notes and validations:
- Region spacing requirement in your IA file text:
  - First region must NOT start with a space
  - All subsequent regions MUST start with a single leading space
  - Violations are reported with row/region details and must be corrected
- Region column names are matched robustly (case-insensitive; with/without `$`), and helpful errors are shown when missing
- You can Save/Load your Text IA configuration (`*.mat`) and the plugin auto-saves the last-used configuration to `last_text_ia_config.mat`
- Optional: Save intermediate dataset(s) after IA processing but before labeling. Files use `*_eyesort_ia.set`

Under the hood (`functions/compute_text_based_ia.m`):
- Builds per-trial region and word pixel boundaries from your text using `offset` and `pxPerChar`
- Assigns region info to events and identifies fixation membership per region
- Performs trial labeling (first pass, regressions, etc.) via `functions/trial_labeling.m`
- Stores field-name metadata in `EEG.eyesort_field_names` and region names in `EEG.region_names`

Experimental: Pixel-based IA (`pop_load_pixel_ia`) exists but the main menu keeps it disabled. You may call it directly for pilot workflows.

#### 3) Eye-Tracking Event Labeling

Use `EyeSort → 3. Eye-Tracking Event Labeling` (`pop_label_datasets`):

- Select time-locked region(s) to anchor your label criteria
- Choose pass constraints: First, Second, Third+ (or any)
- Optionally constrain by previous and/or next region visited
- Select fixation type: Single, First of Multiple, Second, Subsequent, Last in Region
- Select saccade direction In and Out: Forward or Backward
- Enter a human-readable Label Description (used later for BDF descriptions)
- Save/Load label configurations (`*.mat`); last-used config is auto-saved to `last_label_config.mat`

Behavior and outputs:
- Each applied label increments a label counter and rewrites matching event `type` values as a 6-digit code: `CCRRLL`
  - `CC` = 2-digit condition code
  - `RR` = 2-digit region code (stable mapping per dataset/region order)
  - `LL` = 2-digit label number (01–99)
- Original event types are preserved in `event.original_type`
- Labeled events also receive `event.eyesort_*` fields and, when Label Description is set, BDF description strings
- Single dataset mode updates the current `EEG` structure in place; batch mode writes progressively to your chosen output directory as `*_processed.set`

#### 4) Generate BINLISTER BDF File

Use `EyeSort → Generate BINLISTER BDF File` (`pop_generate_bdf` → `functions/generate_bdf_file.m`):

- Scans labeled events and groups unique `CCRRLL` codes by condition and region
- Writes a BINLISTER-compatible BDF (default name `eyesort_bins.txt`)
- Uses your Label Description and condition descriptors to build readable bin text when available

#### Save Labeled Dataset

Use `EyeSort → Save Labeled Dataset` to pick and save the current (or one from `ALLEEG`) with standard EEGLAB dialogs.

### Batch processing (scripted)

For fully scripted pipelines, see `functions/eyesort_batch_process.m` for an example that:

1) Loads each `.set`
2) Runs `compute_text_based_ia` using a saved config (`.m` or `.mat`)
3) Applies label filters via `label_datasets_core` using a saved label config
4) Saves intermediate and final outputs (`*_eyesort_ia.set`, `*_eyesort_processed.set`)

### Configuration files

- Text IA configs: `Save Configuration`/`Load Configuration` in the Text IA GUI; last-used auto-saved to `last_text_ia_config.mat`
- Label configs: `Save Label Configuration`/`Load Label Configuration` in the Labeling GUI; last-used auto-saved to `last_label_config.mat`
- You can store configs anywhere; EyeSort will also look for the `last_*.mat` files in the plugin directory

### Troubleshooting

- No `EyeSort` menu in EEGLAB:
  - Ensure `EyeSort/` is inside `eeglab/plugins/` when launching EEGLAB
  - Check the MATLAB path for duplicate copies; EyeSort uses the first found
- “EEG data is not properly processed with region information”: run Step 2 (Text IA) first
- “No labeled events found”: your criteria may be too strict, or events already carry prior labels; relax options or clear conflicts
- IA file errors:
  - Missing region columns or mismatched names — verify headers match your GUI inputs
  - Region spacing rule violated — first region no space; subsequent regions start with one space
- Eye event field names differ from defaults — enable “Change default event field names” in the Text IA GUI and supply your names

### What EyeSort writes

- Intermediate (optional): `*_eyesort_ia.set`
- Labeled outputs (batch): `*_processed.set`
- BDF: `eyesort_bins.txt` (or your chosen name/path)
- Metadata fields on events/dataset for traceability (e.g., `eyesort_full_code`, `eyesort_label_descriptions`, `eyesort_field_names`)

### Citation and license

- To be included...
- License: 

### Contact and help

- Use `EyeSort → Help` to open `help.txt` (stub). For detailed docs, use this README.
- Issues and questions: open a ticket on the repository.