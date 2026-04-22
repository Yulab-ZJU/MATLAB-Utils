function resetCallerState()
%RESETCALLERSTATE  Clean common visible state in the caller workspace.
%
% This function clears variables in the caller workspace, closes figures,
% clears the command window, closes open file handles, deletes timers,
% and closes an existing parallel pool if present.
%
% Note:
%   - It operates on the caller workspace via EVALIN.
%   - It does NOT fully reset MATLAB to startup state.
%   - It does NOT clear persistent states, loaded functions, class
%     definitions, path changes, warning states, RNG state, etc.

    evalin("caller", [
        "clearvars; " ...
        "close all force; " ...
        "clc; " ...
        "fclose('all'); " ...
        "try, delete(timerfindall); end; " ...
        "p = gcp('nocreate'); if ~isempty(p), delete(p); end;"
    ]);
end