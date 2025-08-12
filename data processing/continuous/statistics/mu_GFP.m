function gfp = mu_GFP(data, chs2Ignore)
% Compute global field power for multi-channel data.
% If [data] is a [nch x nsample] matrix (ERP), return [1 x nsample] GFP.
% If [data] is trial data ([ntrial x 1] cell with [nch x nsample] data), 
% return [ntrial x nsample] GFP.
% Optional input [chs2Ignore] specifies channel numbers excluded from 
% GFP computation.

narginchk(1, 2);

if nargin < 2
    chs2Ignore = [];
end

switch class(data)
    case 'cell' % compute GFP for each trial
        [nch, ~] = mu.checkdata(data);
        data = cat(3, data{:}); % [nch x nsample x ntrial]

        channels = setdiff(1:nch, chs2Ignore);
        nchValid = numel(channels);
        data = data(channels, :, :);

        gfp = squeeze(sqrt(sum((data - mean(data, 1)) .^ 2, 1) / nchValid))'; % [ntrial × nsample]

    case {'double', 'single'} % compute GFP for ERP
        nch = size(data, 1);
        channels = setdiff(1:nch, chs2Ignore);
        nchValid = numel(channels);
        data = data(channels, :);
        gfp = sqrt(sum((data - mean(data, 1)) .^ 2, 1) / nchValid); % [1 x nsample]

    otherwise
        error("mu_GFP:InvalidDataType", "Invalid data type. Must be cell array or numeric matrix.");
end

return;
end