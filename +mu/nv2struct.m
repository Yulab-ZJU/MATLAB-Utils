function S = nv2struct(nv)
%NV2STRUCT Convert name-value cell array to struct safely

arguments
    nv (:,1) cell
end

assert(mod(numel(nv), 2) == 0, 'Name-value list must have even length.');

names = nv(1:2:end);
vals  = nv(2:2:end);

% force string → char, make valid names
names = matlab.lang.makeValidName(string(names));
names = cellstr(names);

% check duplicates
if numel(unique(names)) < numel(names)
    error('Duplicate name-value keys detected.');
end

S = cell2struct(vals, names, 2);

return;
end
