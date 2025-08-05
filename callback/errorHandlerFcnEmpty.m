function varargout = errorHandlerFcnEmpty(S, varargin)
for index = 1:nargout
    varargout{index} = [];
end

return;
end