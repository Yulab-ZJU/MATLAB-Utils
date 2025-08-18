function varargout = rowfun(fcn, A, varargin)
% Description: apply fcn along the first dimension of [A] (based on cellfun)
% Notice:
%     Inputs can be all data type valid for mat2cell().
%     Cell arrays can also be segmented by mat2cell().
% Input:
%     fcn: function handle, function to apply to each row
%     A: a N-D data of any type
%     B1,...,Bn: same as [A]
%     "UniformOutput": true/false (default=true)
%     "ErrorHandler": function handle of error
% Output:
%     When "UniformOutput" is set false, return size(A,1)*1 cell with results of fcn(a,...)
%     When "UniformOutput" is set true, return size(A,1)*1 vector
% Example:
%     C = mu.rowfun(@mFcn, A, B, "UniformOutput", false);

[varargout{1:nargout}] = mu.slicefun(fcn, 1, A, varargin{:});
return;
end
