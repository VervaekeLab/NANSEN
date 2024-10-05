classdef HasSessionData < uim.handle
%HasSessionData Mixin to provide SessionData to a class
%
%   This class overrides the subsref to initialize the Data upon the first
%   subsref request. Updating all the variables of the SessionData has some
%   overhead, so only want this to happen when necessary.
%
%   The reason for not adding the subsref directly to a class having a
%   Data property is because overriding the subsref method can render the
%   original class not to work as intended.

%   I later found out that, of course, the class that inherits this
%   superclass will also inherit the subsref method, so back to square 1.
%
%   Update: Seems like overriding the numArgumentsFromSubscript method and
%   calling the builtin from there gives the expected behavior. Needs some
%   stress testing.
%
%   Conclusion: Would be nice to solve this in a more elegant way...

%   Note: The "Data" property is transient because it might potentially
%   contain a lot of in-memory cached data which should not be saved. As the
%   transient properties do not follow an object if it is sent to a
%   separate worker, the Data property is dependent and there is a private
%   property containing the SessionData object. If the Data object is empty
%   or invalid a new Data object is created.

    properties (Dependent, Transient)
        Data nansen.session.SessionData
    end

    properties (Transient, Access = private)
        Data_ nansen.session.SessionData
    end

    methods
        function obj = HasSessionData()
            % Assign data for each obj individually
            for i = 1:numel(obj)
                obj(i).Data_ = nansen.session.SessionData(obj(i)); %#ok<AGROW>
            end
        end

        function delete(obj)
            delete(obj.Data_)
        end
    end
    
    methods % Set/get

        function data = get.Data(obj)
            % Reinitialize data if it is empty
            for i = 1:numel(obj)
                if isempty(obj(i).Data_)
                    obj(i).Data_ = nansen.session.SessionData(obj(i));
                end
            end
            data = obj.Data_;
        end
    end

% %         Todo: Is this even possible without breaking my head. How to
% %         properly output stuff from properties that i.e contains struct
% %         arrays.

    methods (Sealed, Hidden)

        function varargout = subsref(obj, s)
            
% %             numRequestedOutputs = nargout();
% %             if numRequestedOutputs == 0
% %                 numOutputs = obj.determineNumArgout(s); %#ok<NASGU>
% %             else
% %                 numOutputs = numRequestedOutputs;
% %             end

            numOutputs = nargout;
            varargout = cell(1, numOutputs);
            
            [isDataRequested, ind] = obj.isDataSubsrefed(s);
            
            if isDataRequested
                for i = ind
                    if ~obj(i).Data.IsInitialized
                        obj(i).Data.initialize();
                    end
                end
            end
            
            % If we got this far, use the builtin subsref
            if numOutputs > 0
                [varargout{:}] = builtin('subsref', obj, s);
            else
                builtin('subsref', obj, s)
            end
            
% %                 varargout = builtin('subsref', obj, s);
% %                 try
% %                     varargout{1} = builtin('subsref', obj, s);
% %                 catch ME
% %                     switch ME.identifier
% %                         case {'MATLAB:TooManyOutputs', 'MATLAB:maxlhs'}
% %                             try
% %                                 builtin('subsref', obj, s)
% %                             catch ME
% %                                 rethrow(ME)
% %                             end
% %                         otherwise
% %                             rethrow(ME)
% %                     end
% %                 end
% %             end
            
% %             if numRequestedOutputs == 0
% %                 varargout{:}
% %                 clear varargout
% %             end
        end
        
        function n = numArgumentsFromSubscript(obj, s, indexingContext)
            if strcmp(s(1).type, '.')
                if strcmp(s(1).subs, 'Data')
                    for i = 1:numel(obj)
                        if ~obj(i).Data.IsInitialized
                            obj(i).Data.initialize();
                        end
                    end
                end
            end
            
            n = builtin('numArgumentsFromSubscript', obj, s, indexingContext);
        end
    end

    methods (Access = private)

        function [tf, idx] = isDataSubsrefed(obj, s)
            
            if strcmp(s(1).type, '.') && strcmp(s(1).subs, 'Data')
                tf = true;
                idx = 1:numel(obj);
            elseif numel(s) >= 2 && strcmp(s(1).type, '()') ...
                    && strcmp(s(2).type, '.') && strcmp(s(2).subs, 'Data')
                tf = true;
                idx = s(1).subs{1};
            else
                tf = false;
                idx = [];
            end
        end
        
        function numArgouts = determineNumArgout(obj, s)
        %determineNumArgout Determine expected nargout from subsref
        
        % This was an experiment. Did not work very well.
        
            persistent ic
            if isempty(ic)
                ic = enumeration('matlab.mixin.util.IndexingContext');
            end
            
            % Determine the number of expected outputs from each of the
            % indexing contexts
            n = zeros(1, numel(ic));
            for i = 1:numel(ic)
                n(i) = builtin('numArgumentsFromSubscript', obj, s, ic(i));
            end
            
            % Check if different number of outputs are expected and issue
            % warning if yes.
            uniqueN = unique(n);
            if numel(uniqueN) ~= 1
                warning('The number of outputs from this subscripted reference might not be correct')
            end
            
            % Return the value from the "Statement" indexing context
            numArgouts = n(1);
            
        end
    end
end
