function varargout = errorHandlerFcnNAN(S, varargin)
for index = 1:nargout
    varargout{index} = nan;
end

return;
end