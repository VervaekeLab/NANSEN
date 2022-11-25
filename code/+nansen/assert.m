function assert(keyword)
%assert Make an assertion for a given keyword
%
%   nansen.assert(KEYWORD) throws an error if the assertion for the given
%   keyword is not valid.

% Todo: make assertIsInstalled function? Improve that before using the
% code. Can use the same method for checking for presence as in addon
% manager

    switch keyword
        
        case 'StatisticsToolboxInstalled'
            errID = 'Nansen:StatisticsToolboxNotInstalled';
            message = ['The Statistics and Machine Learning toolbox is ', ...
                'required, but is not present. Please install the ', ...
                'toolbox and try again'];
            assertionValid = exist('range', 'file') == 2;
        
        case 'ExtractOnSavepath'
            errID = 'Nansen:ExtractNotFoundOnPath';
            msg = ['EXTRACT is required for this operation, but is not ', ...
                   'found on MATLAB''s search path.'];
            assertionValid = exist('run_extract', 'file') == 2;

        case 'Suite2pOnSavepath'
            errID = 'Nansen:Suite2pNotFoundOnPath';
            msg = ['suite2p is required for this operation, but is not ', ...
                   'found on MATLAB''s search path.'];
            assertionValid = exist('build_ops3', 'file') == 2;
            
        case 'WidgetsToolboxInstalled'
            errID = 'Nansen:WidgetsToolboxNotInstalled';
            msg = ['The Widgets Toolbox is required, but is not ', ...
                   'found on MATLAB''s search path.'];
            assertionValid = exist('widgetsRoot', 'file') == 2;
                
        otherwise
            error('%s is an invalid keyword for nansen.assert', keyword)
            
    end

    if ~assertionValid
        exception = MException(errID, msg);
        throwAsCaller(exception)
    end

end




% Local functions...
function [tf, exception] = assertToolboxInstalled(keyword)
    
    exception = MException.empty;
    
    S = struct();
    
    switch keyword
        case 'ExtractOnSavepath'
            S.ToolboxName = 'EXTRACT';
            S.FunctionName = 'run_extract';
            
        case 'WidgetsToolboxInstalled'
        	S.ToolboxName = 'The Widgets Toolbox';
            S.FunctionName = 'widgetsRoot';
            
        case 'Caiman'
            S.ToolboxName = 'CaImAn';
            S.FunctionName = 'deconvolveCa';
            
    end

    tf = exist(S.FunctionName, 'file') == 2;
    
    if ~tf
        errID = sprintf('Nansen:%sNotInstalled', S.ToolboxName);
        msg = ['%s is required for this operation, but is not ', ...
                   'found on MATLAB''s search path.', S.ToolboxName];
        
        exception = MException(errID, msg);
    end

end


