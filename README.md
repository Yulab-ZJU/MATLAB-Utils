# Initializing MATLAB Utils

To initialize toolbox, run `/initMATLABUtils.m`, which copies `/docs/functionSignatures.json` to `/resources/`.

To stay up-to-date with the latest version, please use Git for version management.:

```shell
git clone git@github.com:Yulab-ZJU:MATLAB-Utils.git
```

# Functions

'\*' marks the most widely-used functions.

### 1. plot

​	`mu.addBars` Adds transparent vertical bars to axes (usually serving as significant areas).

​	\*`mu.addLines` Adds lines to all axes in figures.

​	`mu.addTicks` Adds special ticks and tick labels to specified axis.

​	`mu.addTitle` Adds a title to a figure.

​	`mu.adddWaveError` Adds shaded areas to a curve (usually error bars).

​	\*`mu.autoplotsize` Automatically determines the [row, col] numbers of the subplots based on the total number of subplots in a figure.

​	\*`mu.boxplot` Creates custom grouped boxplots with advanced styling options.

​	`mu.colorbar` Creates a colorbar outside the `tightPosition("IncludeLabels", true)`

​	`mu.copyaxes` Copy the content of one axes to the other (two axes are usually of different sizes).

​	`mu.genColormap` Generates a colormap using white as middle.

​	`mu.genColors` Generates gradient colors with pre-set color pool.

​	`mu.genGradientColors` Generates gradient colors by increasing saturation.

​	`mu.genPolygon` Draws a polygon in the axes and returns its endpoint coordinates and borderlines.

​	\*`mu.histogram` Plots grouped histograms (without overlapping).

​	`mu.mixColors` Mixes two colors with specified ratios to generate a new color.

​	\*`mu.rasterplot` Plots raster data (usually spike-by-trial).

​	\*`mu.scaleAxes` Synchronizes the axis range with advanced settings and UI control.

​	\*`mu.setAxes` Sets the values of axes parameters with name-value pairs. "default" mode will set the axes to be ORIGIN-style.

​	`mu.setLegendOff` Hides legends of targets.

​	\*`mu.subplot` Creates subplot with advanced settings.

​	`mu.syncXY` Synchronizes x-y range.

##### \*Multi-channel data plotting

​	`mu_plotWaveArray` Plots multi-channel and multi-group data of electrode array in one figure.

​	`mu_plotWaveEEG` Plots multi-channel and multi-group EEG data with actual electrode positions.

​	`mu_topoplotArray` Plots topographic distribution of specified values on an electrode array.

​	`mu_topoplotEEG` Plots topographic distribution of specified values on the scalp.\

​	`mu_plotTFR` Plots multi-channel time-frequency responses.

------

### 2. data structure

#### 2.1 struct

​	\*`mu.addfield` Adds a new field to [s] or alter the value of an existed field.

​	\*`mu.getor` Returns the structure field or a default if either don't exist.

​	\*`mu.getorfull` Complete [s] with [default]. [default] is specified as a struct containing some fields of [s] with default values.

​	`mu.getVarsFromWorkspace` Finds variables in workspace using regular expression.

​	\*`mu.parsestruct` Parses fields of struct [S] and assigns the fields as variables to workspace.

​	`mu.structcat` Concatenate input struct arrays, left empty for fields with conflict.

​	`mu.validatestruct` Validates a struct array by validating each field.

#### 2.2 cell

​	`mu.cell2mat` Advanced `cell2mat`. Elements of the cell can be cell/string/numeric.

​	`mu.reslice` Re-slices a cell array of multi-dimensional arrays along a specified dimension.

​	`mu.parcellfun` Similar to `cellfun` but works in parallel mode.

#### 2.3 matrix

​	`mu.findpeaktrough` Finds indices (in logical) of peak and trough along specified dimension of 2-D data.

​	`mu.findvectorloc` Finds location of vector [pat] in vector [X]. [direction] specifies [locs] of the first or the last index of [pat].

​	`mu.insertrows` Inserts [val] in [X] at specified rows.

​	`mu.lcm` Returns least common multiple of a real array [A].

​	`mu.mapminmax` Maps data to [-ymax, ymax] with zero point unshifted.

​	`mu.max` Returns maximum value of time series data [X] and the corresponding time [t].

​	`mu.min` Returns minimum value of time series data [X] and the corresponding time [t].

​	`mu.perms` Returns a N^k-by-k matrix containing all possible permutations of k-element.

​	`mu.replacevalMat` Equals to `X(X == oldVal) = newVal`.

​	`mu.shiftmatrix` Shifts a 2-D matrix by [Nlr, Nud] and pad with specified method.

​	`mu.slicemat` Returns sliced `A(:,...,idx,...,:)` at specified dimension.

#### 2.4 string/char

​	\*`mu.getabspath` Gets absolute path from relative path of a folder or file.

​	\*`mu.getlastpath` Gets the last `end-N+1:end` folder path of path [P].

​	\*`mu.getrootpath` Gets N-backward root path of path [P].

#### 2.5 function_handle

​	`mu.obtainArgoutN` Returns the [fcn] outputs of specified ordinal numbers.

​	`mu.path2func` Gets function handle from the full path of an M file.

#### 2.6 array (any type)

​	`mu.pararrayfun` Similar to `arrayfun` but works in parallel mode.

​	`mu.parrowfun` Similar to `mu.rowfun` but works in parallel mode.

​	`mu.parslicefun` Similar to `mu.slicefun` but works in parallel mode.

​	`mu.replaceval` Replaces scalar [x] with [newVal] if [x] is in [conditions] or satisfies conditions(x).

​	\*`mu.rowfun` Applies [fcn] along the first dimension of 2-D matrix or vector [A] (based on cellfun).

​	`mu.slicefun` Applies [fcn] along the dimension [k] of [A] (based on cellfun).

------

### 3. data processing

#### 3.1 filter

​	`mu.filter` General zero-phase multi-channel filter for trial or matrix data. (Require *FieldTrip* toolbox)

#### 3.2 frequency domain

​	`mu.fft` Computes the single-sided amplitude and phase spectrum of input data X using the Fast Fourier Transform (FFT).

​	\*`mu.cwt` Computes cwt results of multi-channel and multi-trial data using parallel computation on GPU.

#### 3.3 trial data (for FieldTrip)

​	`mu.calchMean` Computes the weighted-average [chMean] (nCh\*xx\*xx\*...\*nTime) and NAN-padded [trialsData].

​	`mu.calchErr` Computes the standard error of the mean for [trialsData].

​	`mu.calchStd` Computes the standard deviation of the mean for [trialsData].

​	`mu.calchFunc` Calculate a function over trial data with padding direction.

​	`mu.checkdata` Validates trial data.

​	`mu.cutdata` Cuts trial data within specified time window.

​	`mu.resampledata` Resamples data with a new sample rate.

​	`mu.shuffledata` Shuffle N-D matrix A along specific dimension, with each slice shuffled independently. It is useful when performing permutation test for correlation. For slice shuffled with the same order, use `shuffle`.

##### Preprocessing

​	\*`mu_selectWave` Extracts multi-channel time-series trial data.

​	\*`mu_selectSpikes` Extracts spikes for events (trials).

​	`mu_excludeTrials` Determines bad trials and bad channels using Normalized distribution criteria (exceed 5%-95%).

​	`mu_interpolateBadChannels` Interpolates bad channels by inserting zeros and averaging across neighbors.

​	`mu_prepareNeighboursArray` Generates neighbors for each electrode in an electrode array.

​	`mu_export_Neuracle` Exports trial data recorded in Neuracle system and `EEG App (git@github.com:TOMORI233/EEGApp.git)`. Preprocessing procedures include re-referencing, filtering, epoching, ICA, and trial exclusion.

​	`mu_export_NeuracleJoint` Exports trial data of several protocols at a time.

#### 3.4 statistics

[p, stats, effectSize, bf10] = mu.statfcn(...)

​	`mu.anovan` , `mu.ttest`, `mu.ttest2`, `mu.signrank`, `mu.ranksum`

| Effect size | Cohen’s d (*t*-test) | $\eta^2$ or partial $\eta^2$ (ANOVA) | Rank-Biserial Correlation (Mann–Whitney U、Wilcoxon test) |
| ----------- | -------------------- | ------------------------------------ | --------------------------------------------------------- |
| Small       | 0.2                  | 0.01                                 | 0.1                                                       |
| Medium      | 0.5                  | 0.06                                 | 0.3                                                       |
| Large       | 0.8                  | 0.14                                 | 0.5                                                       |

​	`mu.prepareANOVA` Prepares group data for ANOVA.

​	`mu.histcounts` Calculates hist counts for overlapped bins.

​	`mu.fisherstat` Calculates joint p-value with Fisher's method.

​	`mu.se`  Calculates standard error of [x] along [dim].

#### 3.5 ICA

​	`mu_ica` Performs independent component analysis (ICA) on trial data.

​	`mu_ica_reconstructData` Reconstruct trial data by removing selected independent components.

#### 3.6 Granger causality

​	`mu_granger` Computes Granger causality (GC) of trial data using parametric/non-parametric methods.

​	`mu_granger_wavelet` Computes GC of wavelet transformed data using non-parametric method.

​	`mu_gMI`  Computes global Moran's I.

​	`mu_gMI_rcWeightMat` Builds contiguity weights matrix for electrode map [nX,nY].

#### 3.7 source analysis

​	`mu_source` Performs source analysis on trial data.

​	`mu_source_config` and `mu_source_prepareData` Prepare covariance matrix and electrode/anatomical data before source analysis.

​	`mu_source_plot` Plots source analysis result in 2-D and 3-D view.

#### 3.8 permutation test

​	`mu_cbpt` Performs cluster-based permutation test on trial data.

------

### 4. stimulus generation

​	`mu.ctgen` Generates click trains with specified inter-click interval sequences.

​	`mu.tonegen` Generates pure tones or complex tones.

​	`mu.genRiseFallEdge` Generates rise-fall edges for sound wave.

------

### 5. file

​	`mu.exportFigure2PDF` Exports a figure to PDF file with specified [with, height] in mm.

​	`mu.exportgraphics` Advanced `exportgraphics` allowing axes array as input (for overlapped axes).

​	`mu.load` Skip loading if variables exist in workspace.

​	`mu.print` Skip printing if file exists.

​	`mu.save` Skip saving if file exists.

​	`mu.syncRepositories` Updates all GIT repositories in the specified root path.

------

### 6. UI

​	\*`ccc` Equals to `clear;close all;clc;`

​	`validateinput` Loops input until validation passes.



​	`colorpicker` Picks color from screen.

​	`addLinesApp` UI control for `mu.addLines`.

​	`scaleAxesApp` UI control for `mu.scaleAxes`.

​	`validateinputApp` UI control for `validateinput`.

------

### 7. callback handler function

Used for 'ErrorHandler' input in `arrayfun`, `cellfun`, `mu.rowfun`, `mu.slicefun`, `mu.par***fun`

​	`errNAN`, `errEmpty` Returns []/NAN if error occurs.

​	`onTargetDeleteFcn` This function is registered as the `deleteFcn` of an axes target `src.UserData.apps` is a cell array containing multiple apps.

------

### 8. toolbox API

#### 8.1 512 system

​	`readrhd` Reads Intan Technologies RHD data file generated by Intan USB interface.

#### 8.2 FieldTrip

​	`ft_promotepaths` Set FielTrip paths to top.

​	`ft_removepaths` Remove FieldTrip paths but reserve `ft_defaults`.

#### 8.3 kilosort

​	`kilosort3` API for kilosort3

​	`kilosort4` Runs kilosort4 (python version) via MATLAB.

​	`checkPython` Converts system python version to `3.7` for kilosort3.

​	`parseNPY` Reads sort results from NPY files.

#### 8.4 psignifit

​	`pfit` Customized API for using `psignifit`.

​	`fitBehavior`

#### 8.5 PTB-3

​	`KbGet` Gets keyboard press within a time window.

​	`playAudio` Plays audio from a signal or file under ptb-3 control.
