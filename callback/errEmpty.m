function varargout = errEmpty(err, varargin)
% [err] is  is a structure with these fields:
% identifier — Error identifier
% message — Error message text
% index — Linear index into the input arrays at which func threw the error
%
% This function is called as ErrorHandler of arrayfun, cellfun, ...

varargout = cell(1, nargout);
[varargout{:}] = deal([]);
return;
end