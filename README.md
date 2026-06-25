# MATLAB-Utils

Integrated MATLAB utilities for data processing, visualization, statistics, electrophysiology workflows, and UI helpers.

This repository is organized around the MATLAB package `+mu`, standalone preprocessing and toolbox APIs, callback handlers, and UI apps. Functions marked as external-toolbox wrappers may require FieldTrip, EEGLAB, Psychtoolbox, Kilosort, psignifit, or other third-party dependencies.

## Installation and initialization

Clone the repository and run the initializer from MATLAB:

```matlab
git clone git@github.com:Yulab-ZJU/MATLAB-Utils.git
cd MATLAB-Utils
initMATLABUtils
```

To update the local copy:

```matlab
updateMATLABUtils
```

`initMATLABUtils.m` adds the required repository paths to MATLAB. `updateMATLABUtils.m` updates the toolbox from Git.

## Public function index

### 1. Plotting and figure utilities in `+mu`

| Function | Purpose |
|---|---|
| `mu.addBars` | Add transparent vertical or horizontal bars to axes, commonly used to mark significant time windows. |
| `mu.addDataTips` | Attach custom data-tip rows to line, patch, scatter, or mixed graphics objects, with backward compatibility for older MATLAB data cursor behavior. |
| `mu.addLines` | Add reference lines to all or selected axes in figures. |
| `mu.addTicks` | Add custom tick positions and labels to a specified axis. |
| `mu.addTitle` | Add a figure-level title. |
| `mu.addWaveError` | Add shaded error regions around a curve, typically for SEM, SD, or confidence intervals. |
| `mu.autoplotsize` | Automatically choose subplot row and column counts from the number of panels. |
| `mu.boxplot` | Draw highly customizable grouped boxplots with control over error type, center line, raw data points, outliers, colors, and spacing. |
| `mu.colorbar` | Create a colorbar outside a tight-positioned axes layout. |
| `mu.copyaxes` | Copy plotted content from one axes to another, useful when source and target axes have different sizes. |
| `mu.dashline` | Draw dashed curves by segmenting polylines in data-space arc length instead of relying on MATLAB line style. |
| `mu.dotplot` | Draw dot or swarm plots with optional spread interval, center line, confidence interval, links between paired groups, and horizontal or vertical orientation. |
| `mu.genColormap` | Generate a diverging colormap with white or a light color near the center. |
| `mu.genColors` | Generate gradient or grouped colors from a predefined color pool. |
| `mu.genGradientColors` | Generate related colors by changing saturation or brightness. |
| `mu.genPolygon` | Draw a polygon on axes and return endpoint coordinates and border handles. |
| `mu.groupFigures` | Group multiple figures into tabs of one figure. MATLAB R2025a or newer is recommended. |
| `mu.histogram` | Plot grouped histograms without overlap. |
| `mu.image` | Display image-like matrix data with helper defaults for axes and color handling. |
| `mu.mixColors` | Mix two RGB colors using specified weights. |
| `mu.moveaxes` | Move one or more axes by changing position coordinates. |
| `mu.polarhistogram` | Draw polar histograms with custom styling options. |
| `mu.rasterplot` | Plot raster data, typically spike times across trials. |
| `mu.scaleAxes` | Synchronize and scale axes limits with advanced options and UI support. |
| `mu.setAxes` | Set axes properties through name-value pairs. The `default` mode applies ORIGIN-style formatting. |
| `mu.setLegendOff` | Hide legends for selected targets. |
| `mu.setPlotMode` | Switch plot display mode or graphical state for selected plot objects. |
| `mu.subplot` | Create subplots with advanced control of margins, spacing, and panel sizes. |
| `mu.tiledlayout` | Create tiled layout with advanced control of margins, spacing, and panel sizes. |
| `mu.syncXY` | Synchronize x and y axis ranges. |

### 2. Data structure, array, and utility functions in `+mu`

#### 2.1 Struct utilities

| Function | Purpose |
|---|---|
| `mu.addfield` | Add a new field to a struct or update an existing field. |
| `mu.getor` | Return a struct field value if present, otherwise return a default value. |
| `mu.getorfull` | Fill missing fields in a struct using values from a default struct. |
| `mu.getVarsFromWorkspace` | Find variables in a workspace using regular expressions. |
| `mu.nv2struct` | Convert name-value pairs to a struct. |
| `mu.nvdropempty` | Remove empty entries from name-value pairs or name-value structs. |
| `mu.nvnorm` | Normalize name-value input, often for consistent lower-case or canonical option names. |
| `mu.parsestruct` | Parse fields of a struct and assign them as variables in the caller workspace. |
| `mu.struct2nv` | Convert a struct into name-value pairs. |
| `mu.structcat` | Concatenate struct arrays while handling missing or conflicting fields. |

#### 2.2 Cell utilities

| Function | Purpose |
|---|---|
| `mu.cell2mat` | Extended `cell2mat` supporting cells containing numeric arrays, strings, chars, or nested cells. |
| `mu.cellcat` | Concatenate the contents of a cell array along a specified dimension. |
| `mu.parcellfun` | Parallel version of `cellfun`. |
| `mu.reslice` | Re-slice a cell array of multidimensional arrays along a selected dimension. |

#### 2.3 Matrix and numeric utilities

| Function | Purpose |
|---|---|
| `mu.findpeaktrough` | Find logical indices of peaks and troughs along a selected dimension in 2-D data. |
| `mu.findvectorloc` | Locate a vector pattern inside another vector and return first or last matching index. |
| `mu.ifelse` | Inline conditional helper returning one of two values based on a condition. |
| `mu.insertrows` | Insert rows with a specified value into an array. |
| `mu.lcm` | Compute the least common multiple for real-valued numeric arrays using rational approximation. |
| `mu.mapminmax` | Map data to a symmetric range while keeping zero unshifted. |
| `mu.max` | Return maximum values of time-series data and corresponding time points. |
| `mu.min` | Return minimum values of time-series data and corresponding time points. |
| `mu.nchoosek` | Extended combination helper based on `nchoosek`. |
| `mu.numstrcat` | Concatenate numeric values into formatted strings. |
| `mu.perms` | Return all possible k-element permutations from N elements. |
| `mu.replaceval` | Replace scalar values that match specified values or satisfy condition functions. |
| `mu.replacevalMat` | Matrix-specific helper equivalent to `X(X == oldVal) = newVal`. |
| `mu.shiftmatrix` | Shift a 2-D matrix left-right or up-down and pad missing values by a chosen method. |
| `mu.shortest_k_subseq` | Find the shortest subsequence satisfying a k-related criterion. |
| `mu.slicemat` | Return `A(:,...,idx,...,:)` along a specified dimension. |

#### 2.4 String, path, and function-handle utilities

| Function | Purpose |
|---|---|
| `mu.getabspath` | Convert a relative folder or file path to an absolute path. |
| `mu.getlastpath` | Return the final `N` folders or file components from a path. |
| `mu.getrootpath` | Return an N-level parent path from an input path. |
| `mu.isTextScalar` | Test whether input is a scalar string or char. |
| `mu.obtainArgoutN` | Return selected output arguments from a function call. |
| `mu.path2func` | Convert a full `.m` file path into a function handle. |

#### 2.5 Function application and parallel helpers

| Function | Purpose |
|---|---|
| `mu.pararrayfun` | Parallel version of `arrayfun` with support for multiple inputs and error handlers. |
| `mu.parrowfun` | Parallel version of `mu.rowfun`. |
| `mu.parslicefun` | Parallel version of `mu.slicefun`. |
| `mu.rowfun` | Apply a function along the first dimension of a vector or 2-D matrix. |
| `mu.slicefun` | Apply a function along a selected dimension of an array. |

#### 2.6 State and object helpers

| Function or class | Purpose |
|---|---|
| `mu.OptionState` | Unified on/off state class. Converts logical, numeric, or strings such as `on`, `off`, `show`, `hide`, `yes`, and `no` into a standard state. |
| `mu.dispstate` | Overwrite and update command-window status messages in place. |
| `mu.getObjVal` | Retrieve values from objects, structs, tables, or containers using flexible field or property access. |

### 3. Data processing functions in `+mu`

#### 3.1 Filtering and time-frequency analysis

| Function | Purpose |
|---|---|
| `mu.filter` | Zero-phase multi-channel filtering for matrix or trial data. FieldTrip may be required. |
| `mu.fft` | Compute single-sided FFT amplitude and phase spectra. |
| `mu.cwt` | Compute continuous wavelet transform for multi-channel and multi-trial data, with optional parallel or GPU acceleration. |

#### 3.2 Trial-data utilities

| Function | Purpose |
|---|---|
| `mu.calchMean` | Compute weighted-average channel data and return NaN-padded trial data. |
| `mu.calchErr` | Compute standard error across trials. |
| `mu.calchStd` | Compute standard deviation across trials. |
| `mu.calchFunc` | Apply a function to trial data with configurable padding direction. |
| `mu.checkdata` | Validate trial-data structure and consistency. |
| `mu.cutdata` | Cut trial data within a specified time window. |
| `mu.resampledata` | Resample trial or continuous data to a new sampling rate. |
| `mu.shuffledata` | Shuffle an N-D matrix along a selected dimension, independently for each slice. Useful for permutation tests. |

#### 3.3 Statistics

| Function | Purpose |
|---|---|
| `mu.anovan` | Wrapper around ANOVA with unified output format and effect-size handling. |
| `mu.ttest` | Wrapper around one-sample or paired t-test with unified output format. |
| `mu.ttest2` | Wrapper around independent-samples t-test with unified output format. |
| `mu.signrank` | Wrapper around Wilcoxon signed-rank test with unified output format. |
| `mu.ranksum` | Wrapper around Mann-Whitney U or rank-sum test with unified output format. |
| `mu.prepareANOVA` | Prepare data and grouping variables for ANOVA. |
| `mu.histcounts` | Calculate histogram counts for overlapping bins. |
| `mu.fisherstat` | Combine p-values using Fisher's method. |
| `mu.fdr` | Apply false-discovery-rate correction to p-values. |
| `mu.se` | Compute standard error along a selected dimension. |

#### 3.4 Stimulus generation

| Function | Purpose |
|---|---|
| `mu.ctgen` | Generate click trains using specified inter-click-interval sequences. |
| `mu.tonegen` | Generate pure tones or complex tones. |
| `mu.tbgen` | Generate tone burst trains. |
| `mu.genRiseFallEdge` | Generate rise-fall ramps for sound waveforms. |

#### 3.5 File and repository helpers

| Function | Purpose |
|---|---|
| `mu.exportFigure2PDF` | Export a MATLAB figure to PDF with specified width and height in millimeters. |
| `mu.exportgraphics` | Extended `exportgraphics` supporting axes arrays and overlapped axes. |
| `mu.load` | Load variables while skipping loading if variables already exist in the workspace. |
| `mu.print` | Print or export figures while skipping existing files. |
| `mu.save` | Save variables while skipping existing files unless overwrite behavior is requested. |
| `mu.syncRepositories` | Update all Git repositories under a specified root path. |

### 4. Continuous electrophysiology and EEG processing

#### 4.1 EEG electrode configuration

| Function or resource | Purpose |
|---|---|
| `EEGPos_Neuracle32` | Provide or generate channel-position information for a 32-channel Neuracle EEG layout. |
| `EEGPos_Neuracle64` | Provide or generate channel-position information for a 64-channel Neuracle EEG layout. |
| `EEGPos_Neuroscan64` | Provide or generate channel-position information for a 64-channel Neuroscan EEG layout. |
| `Neuracle_chan32.loc` | Electrode location file for Neuracle 32-channel layout. |
| `Neuracle_chan64.loc` | Electrode location file for Neuracle 64-channel layout. |
| `Neuroscan_chan64.loc` | Electrode location file for Neuroscan 64-channel layout. |
| `Standard-10-5-Cap385.sfp` | Standard 10-5 electrode-position file copied from EEGLAB. |

#### 4.2 Continuous-data plotting

| Function | Purpose |
|---|---|
| `mu_plotTFR` | Plot multi-channel time-frequency responses. |
| `mu_plotWaveArray` | Plot multi-channel and multi-group time series on an electrode-array layout. |
| `mu_plotWaveEEG` | Plot multi-channel EEG waveforms using real electrode positions. |
| `mu_scaleplate` | Add a scale plate to figures with multiple subplots. |
| `mu_topoplotArray` | Plot topographic values on an electrode-array grid. |
| `mu_topoplotEEG` | Plot scalp topographies using EEG channel positions. |

#### 4.3 Generic preprocessing

| Function | Purpose |
|---|---|
| `mu_selectWave` | Extract multi-channel time-series trial data from continuous recordings. |
| `mu_excludeTrials` | Detect bad trials and bad channels using normalized distribution criteria. |
| `mu_interpolateBadChannels` | Interpolate bad channels by inserting zeros or averaging neighboring channels. |
| `mu_prepareNeighboursArray` | Generate neighboring-channel definitions for electrode arrays. |

#### 4.4 Neuracle EEG preprocessing

| Function | Purpose |
|---|---|
| `mu_export_Neuracle` | Export trial data recorded by a Neuracle system and EEG App workflow. Includes rereferencing, filtering, epoching, ICA, and trial exclusion. |
| `mu_export_NeuracleJoint` | Export trial data from multiple protocols together. |
| `mu_preprocess_configEEG` | Build preprocessing configuration for EEG workflows. |
| `mu_preprocess_generalProcessFcn` | General processing function used by EEG preprocessing pipelines. |
| `mu_unwrapTrialEvents` | Convert or unwrap trial-event structures into a format suitable for preprocessing. |

#### 4.5 Independent component analysis

| Function | Purpose |
|---|---|
| `mu_ica` | Perform ICA on trial data. |
| `mu_ica_reconstructData` | Reconstruct trial data after removing selected independent components. |

#### 4.6 Granger causality and spatial statistics

| Function | Purpose |
|---|---|
| `mu_granger` | Compute Granger causality for trial data using parametric or nonparametric methods. |
| `mu_granger_wavelet` | Compute nonparametric Granger causality from wavelet-transformed data. |
| `mu_granger_wavelet_pt` | Perform permutation testing for wavelet-based Granger causality contrasts. |
| `mu_gMI` | Compute global Moran's I for spatial autocorrelation. |
| `mu_gMI_rcWeightMat` | Build row-column contiguity weight matrices for electrode maps. |

#### 4.7 Source analysis

| Function | Purpose |
|---|---|
| `mu_source` | Perform source analysis on trial data. |
| `mu_source_config` | Configure source-analysis settings, including electrode and anatomical inputs. |
| `mu_source_prepareData` | Prepare covariance matrices and data structures for source analysis. |
| `mu_source_plot` | Plot source-analysis results in 2-D or 3-D views. |

#### 4.8 Continuous-data statistics

| Function | Purpose |
|---|---|
| `mu_GFP` | Compute global field power for EEG or multichannel field-potential data. |
| `mu_cbpt` | Perform cluster-based permutation testing on trial data. |

### 5. Spike-data processing

| Function | Purpose |
|---|---|
| `mu_selectSpikes` | Extract spike times or spike trains aligned to trial events. |
| `mu_calFR` | Calculate firing rate from spike data. |
| `mu_calLatency` | Estimate response latency from spike responses. |
| `mu_calPSTH` | Calculate peri-stimulus time histograms. |
| `mu_plotFRA` | Plot frequency-response-area results. |
| `mu_plotRaster` | Plot spike rasters. |
| `fraProcessFcn` | Process function for frequency-response-area spike analysis. |
| `noiseProcessFcn` | Process function for noise or noise-response spike analysis. |
| `tciProcessFcn` | Process function for temporal-context or temporal-contrast-index spike analysis. |

### 6. UI and interactive helpers

| Function or app | Purpose |
|---|---|
| `ccc` | Clear workspace, close figures, and clear command window. Equivalent to `clear; close all; clc;`. |
| `resetCallerState` | Reset caller-side state used by interactive utilities. |
| `validateinput` | Repeatedly prompt for input until validation succeeds. |
| `colorpicker` | Pick a color from the screen. |
| `addLinesApp.mlapp` | UI app for interactively controlling `mu.addLines`. |
| `scaleAxesApp.mlapp` | UI app for interactively controlling `mu.scaleAxes`. |
| `validateinputApp.mlapp` | UI app for validated interactive input. |
| `checklist.mlapp` | Checklist-style UI app. |
| `TreeItem` | Helper class used by the checklist UI. |
| `stopwatch` | UI helper for stopwatch-style timing. |

### 7. Callback handlers

These functions are designed for `ErrorHandler` inputs in `arrayfun`, `cellfun`, `mu.rowfun`, `mu.slicefun`, and the parallel `mu.par*fun` helpers.

| Function | Purpose |
|---|---|
| `errEmpty` | Return an empty array when an error occurs. |
| `errNAN` | Return `NaN` when an error occurs. |
| `onTargetDeleteFcn` | Delete callback for axes targets whose `UserData.apps` stores related UI app handles. |

### 8. Toolbox API wrappers

#### 8.1 FieldTrip

| Function | Purpose |
|---|---|
| `ft_promotepaths` | Move FieldTrip paths to the top of the MATLAB search path. |
| `ft_removepaths` | Remove FieldTrip paths while keeping `ft_defaults` available. |

#### 8.2 Intan RHD

| Function | Purpose |
|---|---|
| `readrhd` | Read Intan Technologies `.rhd` data files generated by the Intan USB interface. |

#### 8.3 Kilosort

| Function or folder | Purpose |
|---|---|
| `mu_kilosort3` | Run Kilosort 3 from MATLAB. |
| `mu_kilosort4` | Run the Python version of Kilosort 4 via MATLAB. |
| `chanMap` | Store channel-map files used by Kilosort workflows. |
| `utils` | Helper utilities for Kilosort workflows. |

#### 8.4 psignifit

| Function | Purpose |
|---|---|
| `pfit` | Customized API for fitting psychometric functions with psignifit. |
| `fitBehavior` | Fit behavioral psychometric data using psignifit-related routines. |

#### 8.5 Psychtoolbox

| Function | Purpose |
|---|---|
| `KbGet` | Keyboard input helper for Psychtoolbox experiments. |
| `playAudio` | Audio playback helper for Psychtoolbox experiments. |

#### 8.6 Python integration

| Function or folder | Purpose |
|---|---|
| `mu_pydebug_pycharm` | Configure or attach MATLAB-to-Python debugging for PyCharm workflows. |
| `mu_pydebug_vscode` | Configure or attach MATLAB-to-Python debugging for VS Code workflows. |
| /`functions`/ | Python helper functions called from MATLAB. |

## Notes for contributors

1. Public functions should include a one-line H1 help comment immediately after the function declaration.
2. New functions should be added to the appropriate section of this README.
3. Internal helpers should be placed in `private` folders and normally do not need to be listed here unless users call them directly.
4. For functions requiring external toolboxes, document the dependency in the function help and in this README.

## License

This project is released under the MIT License. See `LICENSE` for details.
