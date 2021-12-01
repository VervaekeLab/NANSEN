function assert(keyword)
%assert Make an assertion for a given keyword
%
%   nansen.assert(KEYWORD) throws an error if the assertion for the given
%   keyword is not valid.

    switch keyword
        
        case 'WidgetsToolboxInstalled'
            
            msg = ['The Widgets Toolbox is required, but is not ', ...
                   'found on MATLAB''s searchpath.'];

            assertionValid = exist('widgetsRoot', 'file') == 2;
                
        otherwise
            error('%s is an invalid keyword for nansen.assert', keyword)
            
    end

    if ~assertionValid
        exception = MException('Nansen:WidgetsToolboxNotInstalled', msg);
        throwAsCaller(exception)
    end

end