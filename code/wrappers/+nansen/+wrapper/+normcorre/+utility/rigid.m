function [M, ref, ncShifts, ncOpts] = rigid(Y, ref, optsFlag)
%rigid Wrapper for running rigid NoRMCorre with default settings.
%   M = rigid(Y, ref) returns motion corrected images M, given uncorrected 
%   images Y. ref is optional and will be calculated if it is not provided.
%
%   [M, ref, ncShifts, ncOpts] = rigid(Y, ref) also returns reference,
%   shifts and options used for motion correction.
%
%   SUPER IMPORTANT: The shifts returned by normcorre follows matlab array 
%   indexing convention, so the first dimension of shifts are always the
%   shifts in the y-dimension, and the second dimension of shifts are
%   always in the x-dimension. The ncShifts.shifts field is a 4D array,
%   containing [i, j, k, ndim]. i, j, and k are the shifts for subsquares,
%   so these dimensions have length 1 for rigid alignment, and ndim is the 
%   number of shift dimensions. To get the x shifts for a rigid alignment, 
%   use the syntax dx = ncShifts.shifts(1,1,1,2);


if nargin < 2; ref = []; end
if nargin < 3; optsFlag = 'standard'; end

if ~isa(Y, 'single') || ~isa(Y, 'double')
    Y = single(Y);
    ref = single(ref);
end

switch optsFlag
    
    case 'standard'
        ncOpts = NoRMCorreSetParms( ...
                    'd1', size(Y,1), 'd2', size(Y,2), 'max_shift', 50, ...
                    'bin_width', 60, 'us_fac', 50, 'print_msg', 0, 'boundary', 'copy', ...
                    'shifts_method', 'cubic');
    case 'fft'
        ncOpts = NoRMCorreSetParms( ...
                    'd1', size(Y,1), 'd2', size(Y,2), 'max_shift', 50, ...
                    'bin_width', 60, 'us_fac', 50, 'print_msg', 0, 'boundary', 'copy', ...
                    'shifts_method', 'fft');
end

    
if isempty(ref)
    [Y, ncShifts, ref] = normcorre(Y, ncOpts);
else
    [Y, ncShifts, ref] = normcorre(Y, ncOpts, ref);
end
    
M = cast(Y, 'like', Y);


if nargout == 3
    clear ncOpts
elseif nargout == 2
    clear ncShifts ncOpts
elseif nargout == 1
    clear ref ncShifts ncOpts
end
        
end