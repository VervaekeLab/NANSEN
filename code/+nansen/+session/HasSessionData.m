classdef HasSessionData < uim.handle
%HasSessionData Mixin to provide SessionData to a class
%
%   This class overrides the subsref to initialize the Data upon the first
%   subsref request. Updating all the variables of the SessionData has some
%   overhead, so only want this to happen when necessary. The reason for
%   not adding the subsref directly to a class having a Data property is
%   because overriding the subsref method can render the original class not
%   to work as intended.

    properties
        Data nansen.session.SessionData
    end
    
    methods
        function obj = HasSessionData()
            % Assign data for each obj individually
            for i = 1:numel(obj)
                obj(i).Data = nansen.session.SessionData(obj(i)); %#ok<AGROW>
            end
        end
    end
    
            
% %         Todo: Is this even possible without breaking my head. How to
% %         properly output stuff from properties that i.e contains struct
% %         arrays.

    methods (Sealed, Hidden)

        function varargout = subsref(obj, s)

            % Preallocate cell array of output.
            varargout = cell(1, nargout);
            
            if strcmp(s(1).type, '.')
                if strcmp(s(1).subs, 'Data')
                    for i = 1:numel(obj)
                        if ~obj(i).Data.IsInitialized
                            obj(i).Data.initialize();
                        end
                    end
                end
            end
            
            % If we got this far, use the builtin subsref
            if nargout > 0
                [varargout{:}] = builtin('subsref', obj, s);
            else
                try
                    varargout{1} = builtin('subsref', obj, s);
                catch ME
                    switch ME.identifier
                        case {'MATLAB:TooManyOutputs', 'MATLAB:maxlhs'}
                            try
                                builtin('subsref', obj, s)
                            catch ME
                                rethrow(ME)
                            end
                        otherwise
                            rethrow(ME)
                    end
                end
            end
        end
        
        
% %         function numArgumentsFromSubscript(obj, s)
% %             % useful?
% %         end

    end
end