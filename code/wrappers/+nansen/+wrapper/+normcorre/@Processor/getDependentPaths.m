function pathList = getDependentPaths()
%getDependentPaths Get paths that are needed for running normcorre

    rootDir = utility.path.getAncestorDir( mfilename('fullpath'), 5 );
    nansenDir = strsplit(genpath(rootDir), ':');
    
    % Find local normcorre location
    S = which('NoRMCorreSetParms');
    
    if isempty(S)
        error('Normcorre was not found on MATLAB''s search path')
    end
    
    toolboxPath = fileparts(S);
    
    pathList = [nansenDir(1:end-1), {toolboxPath}];
    
    
    % Todo: 
    %   Need nansen.stack.ImageStack
    %   Need nansen.DataMethod
    %   Need nansen.processing.MotionCorrection
end