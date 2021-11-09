function uTest_LimitFigSize(doSpeed)  %#ok<INUSD>
% Automatic test: LimitFigSize
% This is a routine for automatic testing. It is not needed for processing and
% can be deleted or moved to a folder, where it does not bother.
%
% uTest_LimitFigSize(doSpeed)
% INPUT:
%   doSpeed: Ignored (this is needed for other unit tests only).
% OUTPUT:
%   On failure the test stops with an error.
%
% Tested: Matlab 6.5, 7.7, 7.8, 7.13, WinXP/32, Win7/64
% Author: Jan Simon, Heidelberg, (C) 2012-2015 matlab.2010(a)n(MINUS)simon.de

% $JRev: R-c V:003 Sum:eHWi1tVE0ja1 Date:31-Jul-2015 03:25:59 $
% $License: BSD (use/copy/change/redistribute on own risk, mention the author) $
% $File: Tools\UnitTests_\uTest_LimitFigSize.m $
% History:
% 001: 08-Oct-2012 01:16, First version.

% Initialize: ==================================================================
FuncName = mfilename;
ErrID    = ['JSimon:', FuncName, ':Crash'];

% Do the work: =================================================================
% Hello:
fprintf('==== Test LimitFigSize:  %s\n', datestr(now, 0));

if sscanf(version, '%d', 1) < 7
   fprintf('### LimitFigSize needs Matlab >= 7.0\n');
   return;
end

% Defaults and create a figure implicitly:
disp('  No inputs');
LimitFigSize;

FigH = gcf;
disp('  1 input');
LimitFigSize(FigH);
LimitFigSize('min');       % Set to current size
LimitFigSize([300, 200]);  % Set the minimum

disp('  2 input');
LimitFigSize('min', [300, 200]);
LimitFigSize(FigH,  [300, 200]);
LimitFigSize(FigH,  'min');

disp('  3 inputs');
LimitFigSize(FigH, 'min', [300, 200]);
LimitFigSize(FigH, 'max', [400, 300]);

disp('  Get output');
Limits = LimitFigSize(FigH, 'get');
if ~isequal(Limits.MinSize, [300, 200]) || ~isequal(Limits.MaxSize, [400, 300])
   error(ErrID, 'Limits differ from set values.');
end

disp('  Clear');
LimitFigSize(FigH, 'clear');

delete(FigH);

% Goodbye:
fprintf('LimitFigSize passed the tests.\n');

% return;
