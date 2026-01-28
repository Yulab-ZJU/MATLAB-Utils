function [S, names] = nv2struct(nv, opts)
%NV2STRUCT Convert name-value cell array to struct safely.
%
% [S, names] = nv2struct(nv, 'format','lower'|'upper'|'keep', ...
%                           'dupPolicy','error'|'lastwins', ...
%                           'makeValidName',true|false)
%
% Notes:
% - For NV parsing (e.g. mu.dotplot), it's usually better to NOT change keys
%   (makeValidName=false), and normalize only case for matching.

arguments
    nv cell
    opts.format {mustBeMember(opts.format, {'lower','upper','keep'})} = 'keep'
    opts.dupPolicy {mustBeMember(opts.dupPolicy, {'error','lastwins'})} = 'error'
    opts.makeValidName (1,1) logical = false
end

nv = nv(:).'; % accept any shape, normalize to row
assert(mod(numel(nv),2)==0, 'Name-value list must have even length.');

rawNames = nv(1:2:end);
vals     = nv(2:2:end);

% normalize to string keys
keys = string(rawNames);

% optional: make valid field names (NOT recommended for graphics NV)
if opts.makeValidName
    keys = matlab.lang.makeValidName(keys);
end

% case formatting
switch opts.format
    case 'lower'
        keys = lower(keys);
    case 'upper'
        keys = upper(keys);
    otherwise
        % keep
end

% detect duplicates (case-aware after formatting)
[ukeys, ~, ic] = unique(keys, 'stable');
if numel(ukeys) < numel(keys)
    if opts.dupPolicy == "error"
        % report the first duplicated key(s)
        counts = accumarray(ic, 1);
        dup = ukeys(counts > 1);
        error("Duplicate name-value keys detected: %s", strjoin(dup, ", "));
    else
        % last wins: keep last occurrence
        keep = false(size(keys));
        for i = 1:numel(ukeys)
            idx = find(ic==i, 1, 'last');
            keep(idx) = true;
        end
        keys = keys(keep);
        vals = vals(keep);
    end
end

% build struct (fieldnames must be char)
names = cellstr(keys);
S = cell2struct(vals, names, 2);
end
