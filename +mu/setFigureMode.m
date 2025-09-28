function setFigureMode(mode)
narginchk(0, 1);

if nargin < 1
    mode = 'matlab';
end

assert(mu.isTextScalar(mode), 'Invalid input mode');
mode = validatestring(mode, {'matlab', 'pdf'});

switch lower(mode)
    case 'matlab'
        set(0, "DefaultLineLineWidth"   , "factory");
        set(0, "DefaultPatchLineWidth"  , "factory");
        set(0, "DefaultScatterLineWidth", "factory");
        set(0, "DefaultScatterSizeData" , "factory");
    case 'pdf'
        set(0, "DefaultLineLineWidth"   , 0.3);
        set(0, "DefaultPatchLineWidth"  , 0.3);
        set(0, "DefaultScatterLineWidth", 0.3);
        set(0, "DefaultScatterSizeData" , 1  );
end

return;
end