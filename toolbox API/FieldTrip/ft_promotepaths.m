function ft_promotepaths

try
    pathsAll = path;
    pathsAll = split(pathsAll, ';');
    ftPaths = pathsAll(contains(pathsAll, 'fieldtrip', 'IgnoreCase', true));
    rmpath(ftPaths{:});
    addpath(ftPaths{:}, "-begin");
catch e
    disp(e.message);
end