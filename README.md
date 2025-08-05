# Initialize MATLAB Utils

To initialize toolbox, run `initMATLABUtils.m`



# Functions

'\*' marks the most widely-used functions.

### 1. plot

​	`mu.addBars.m` Adds transparent vertical bars to axes (usually serving as significant areas).

​	\*`mu.addLines.m` Adds lines to all axes in figures.

​	`mu.addTicks.m` Adds special ticks and tick labels to specified axis.

​	`mu.addTitle.m` Adds a title to a figure.

​	`mu.adddWaveError.m` Adds shaded areas to a curve (usually error bars).

​	\*`mu.boxplot.m` Creates custom grouped boxplots with advanced styling options.

​	`mu.colorbar.m` Creates a colorbar outside the `tightPosition("IncludeLabels", true)`

​	`mu.copyaxes.m` Copy the content of one axes to the other (two axes are usually of different sizes).

​	`mu.genColormap.m` Generates a colormap using white as middle.

​	`mu.genColors.m` Generates gradient colors with pre-set color pool.

​	`mu.genGradientColors.m` Generates gradient colors by increasing saturation.

​	`mu.genPolygon.m` Draws a polygon in the axes and returns its endpoint coordinates and borderlines.

​	\*`mu.histogram.m` Plots grouped histograms (without overlapping).

​	`mu.mixColors.m` Mixes two colors with specified ratios to generate a new color.

​	\*`mu.rasterplot.m` Plots raster data (usually spike-by-trial).

​	\*`mu.scaleAxes.m` Synchronizes the axis range with advanced settings and UI control.

​	\*`mu.setAxes.m` Sets the values of axes parameters with name-value pairs. "default" mode will set the axes to be ORIGIN-style.

​	`mu.setLegendOff.m` Hides legends of targets.

​	\*`mu.subplot.m` Creates subplot with advanced settings.

​	`mu.syncXY.m` Synchronizes x-y range.

### 2. data structure

#### 2.1 struct

​	`mu.addfield.m` Adds a new field to [s] or alter the value of an existed field.

​	`mu.`

### 3. data processing

​	``

# Effect size

| Effect size | Cohen’s d (*t*-test) | $\eta^2$ or partial $\eta^2$ (ANOVA) | Rank-Biserial Correlation (Mann–Whitney U、Wilcoxon test) |
| ----------- | -------------------- | ------------------------------------ | --------------------------------------------------------- |
| Small       | 0.2                  | 0.01                                 | 0.1                                                       |
| Medium      | 0.5                  | 0.06                                 | 0.3                                                       |
| Large       | 0.8                  | 0.14                                 | 0.5                                                       |
