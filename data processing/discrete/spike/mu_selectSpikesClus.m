function trial = mu_selectSpikesClus(trial, clus, reserveClus)
%MU_SELECTSPIKESCLUS  Find spikes of specified cluster.
%
%   trial = mu_selectSpikesClus(trial, clus)
%   trial = mu_selectSpikesClus(trial, clus, reserveClus)
%
% INPUTS
%   trial      :   trial spike data (cell or struct)
%   clus       :   cluster index
%   reserveClus:   default=false

narginchk(2, 3);

if nargin < 3
    reserveClus = false;
end

validateattributes(clus, 'numeric', {'vector', 'integer'});

if iscell(trial)
    sz = cellfun(@(x) size(x, 2), trial);
    assert(all(sz == sz(1), 'all'), 'No cluster information found');
    if reserveClus
        trial = cellfun(@(x) x(ismember(x(:, 2), clus(:)), :), trial, "UniformOutput", false);
    else
        trial = cellfun(@(x) x(ismember(x(:, 2), clus(:)), 1), trial, "UniformOutput", false);
    end
elseif isstruct(trial)
    validateattributes(trial, 'struct', {'vector', 'nonempty'});
    assert(isfield(trial, 'spike'), '[trial] should contain field spike');
    if reserveClus
        temp = arrayfun(@(x) x.spike(ismember(x.spike(:, 2), clus(:)), :), trial, "UniformOutput", false);
    else
        temp = arrayfun(@(x) x.spike(ismember(x.spike(:, 2), clus(:)), 1), trial, "UniformOutput", false);
    end
    trial = mu.addfield(trial, "spike", temp);
else
    error('Invalid data type %s. It should either be cell or struct.', class(trial));
end

return;
end