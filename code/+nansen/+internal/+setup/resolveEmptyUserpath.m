function resolveEmptyUserpath(options)
%resolveEmptyUserpath - Ask for a folder and make it MATLAB's userpath
%   resolveEmptyUserpath() asks in the Command Window for a folder for
%   user data and passes the answer to
%   nansen.internal.setup.setUserpathFromFolder.
%
%   MATLAB can not read input in batch mode, so there this function throws
%   the error NANSEN:Setup:EmptyUserpathInBatchMode, which says what to run.
%
%   resolveEmptyUserpath(IsBatchMode=TF) uses TF instead of asking MATLAB
%   whether it runs in batch mode.
%
%   See also nansen.internal.setup.setUserpathFromFolder

    arguments
        options.IsBatchMode (1,1) logical = batchStartupOptionUsed()
    end

    if options.IsBatchMode
        error('NANSEN:Setup:EmptyUserpathInBatchMode', ...
            ['MATLAB''s userpath is empty and MATLAB can not ask for a folder in batch mode. ', ...
             'Run userpath("<full path of an existing folder>"), then run nansen_install again.'])
    end

    prompt = [ 'MATLAB''s userpath is empty. Please enter the full path of a ', ...
        'directory which NANSEN \ncan use for saving userdata and ', ...
        'dependencies like addons and toolboxes. \nNote: MATLAB/Nansen will ', ...
        'be appended to the path you enter, and the MATLAB \nsubfolder ', ...
        'becomes MATLAB''s userpath, also in later sessions.\nEnter path name: '];

    answer = input(prompt, 's');
    nansen.internal.setup.setUserpathFromFolder(answer, @askToCreateFolder)
end

function isConfirmed = askToCreateFolder(folder)
%askToCreateFolder - Ask the user whether a missing folder may be created

    % The folder is printed separately because input interprets a
    % backslash in its prompt as an escape sequence
    fprintf('\nThe directory "%s" does not exist.\n', folder)
    answer = input('Do you want to create it?\nEnter "y" for yes or "n" for no: ', 's');
    isConfirmed = strcmpi(strip(answer), 'y');
end
