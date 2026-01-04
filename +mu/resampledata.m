function dataResample = resampledata(data, fs0, fs, opts)
%RESAMPLEDATA Resample data to a new sample rate using resample.m.
%
% INPUT
%   data : vector | matrix | cell
%          - matrix: columns are channels, rows are samples
%          - cell: each cell is a trial; each trial is [nChan x nSample]
%   fs0  : original sampling rate (Hz), positive scalar
%   fs   : target sampling rate (Hz), positive scalar
%
% NAME-VALUE (optional)
%   'RatTol' : tolerance for rat() approximation (default 1e-12)
%
% OUTPUT
%   dataResample : same type as input (cell or numeric), numeric class preserved
%
% NOTES
%   - Requires Signal Processing Toolbox (resample).
%   - For cell trials, this function assumes rows=channels, cols=samples.

arguments
    data
    fs0         (1,1) double {mustBeFinite, mustBePositive}
    fs          (1,1) double {mustBeFinite, mustBePositive}
    opts.RatTol (1,1) double {mustBeFinite, mustBePositive} = 1e-12
end

ratTol = opts.RatTol;

% early exit
if fs == fs0
    dataResample = data;
    return;
end

% Rational ratio
[P, Q] = rat(double(fs) / double(fs0), ratTol);

% Helper: resample along samples dimension for a [nSample x nChan] matrix
% (resample operates down the first dimension)
doResample = @(X) resample(X, P, Q);

if iscell(data)
    % Each trial: [nChan x nSample] -> transpose to [nSample x nChan]
    dataResample = cell(size(data));
    for t = 1:numel(data)
        X = data{t};

        if isempty(X)
            dataResample{t} = X;
            continue;
        end
        if ~(isa(X,"double") || isa(X,"single"))
            error("resampledata:InvalidTrialType", ...
                "Cell trial %d must be single or double, got %s.", t, class(X));
        end

        % rows=channels, cols=samples
        Y = doResample(X.').';   % transpose in, resample, transpose back
        dataResample{t} = Y;
    end

elseif isa(data, "double") || isa(data, "single")
    % Matrix/vector: columns=channels, rows=samples
    dataResample = doResample(data);

else
    error("resampledata:InvalidDataType", ...
        "data must be cell, single, or double. Got %s.", class(data));
end

return;
end
