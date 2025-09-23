function setPlotMode(varargin)
%SETPLOTMODE  Set or restore default plotting properties.
%
% NOTES:
%   - Call setPlotMode before plotting.
%
% USAGE:
%   mu.setPlotMode('matlab')  restores factory defaults
%   mu.setPlotMode('pdf')     sets preset properties for exporting pdf
%   mu.setPlotMode(..., Param1, Val1, ...)  sets other name-value pairs
%
% INPUTS:
%   OPTIONAL:
%     plotMode  - 'matlab' or 'pdf'
%   NAME-VALUE:
%     Parameter names should follow 'TargetProperty' convention
%     (e.g. 'LineLineWidth', 'AxesFontSize').

if nargin == 0
    plotMode = 'pdf';
else
    if matches(varargin{1}, {'matlab', 'pdf'}, "IgnoreCase", true)
        plotMode = varargin{1};
        varargin = varargin(2:end);
    else
        plotMode = 'pdf';
    end
end

mIp = inputParser;
mIp.addOptional("plotMode", "matlab", @mustBeTextScalar);
mIp.KeepUnmatched = true;
mIp.parse(plotMode, varargin{:});

plotMode = validatestring(lower(mIp.Results.plotMode), {'matlab', 'pdf'});
otherParams = mIp.Unmatched;

% --- Validate unmatched params ---
if ~isempty(otherParams)
    fn = fieldnames(otherParams);
    for i = 1:numel(fn)
        paramName = fn{i};
        assert(mu.isTextScalar(paramName), ...
               'Invalid syntax: param name must be text scalar');

        % Require "TargetProperty" style
        validTargets = {'Line', 'Scatter', 'Patch', 'Axes', 'Text', 'Legend', 'Figure'};
        assert(any(startsWith(paramName, validTargets)), ...
               'Invalid property "%s". Must start with one of: %s', ...
               paramName, strjoin(validTargets, ', '));
    end
end

% --- Switch plot mode presets ---
switch plotMode
    case 'matlab'
        % restore factory defaults
        reset(groot);

    case 'pdf'
        % Line width
        set(groot, 'DefaultLineLineWidth'   , 0.3);
        set(groot, 'DefaultScatterLineWidth', 0.3);
        set(groot, 'DefaultPatchLineWidth'  , 0.3);

        % Marker size
        set(groot, 'DefaultLineMarkerSize' , 1);
        set(groot, 'DefaultScatterSizeData', 1); % this only works for `mu.boxplot`

        % Axes
        set(groot, 'DefaultAxesTickDir'   , 'out');
        set(groot, 'DefaultAxesTickLength', [0.01, 0.01]);
        set(groot, 'DefaultAxesFontName'  , 'Arial');
        set(groot, 'DefaultAxesFontSize'  , 7);
        set(groot, 'DefaultAxesFontWeight', 'bold');
        set(groot, 'DefaultAxesBox'       , 'off');
        set(groot, 'DefaultAxesLineWidth' , 0.75);
        set(groot, 'DefaultAxesXColor'    , [0, 0, 0]);
        set(groot, 'DefaultAxesYColor'    , [0, 0, 0]);
        set(groot, 'DefaultAxesLayer'     , 'top');
end

% --- Apply Unmateched params ---
if ~isempty(otherParams)
    val = struct2cell(otherParams);
    for i = 1:numel(fn)
        set(groot, ['Default' fn{i}], val{i});
    end
end

return;
end
