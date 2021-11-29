classdef HasOptions < handle
%nansen.mixin.HasOptions Superclass providing options for a class based method
%

% Should options manager be set only if options are not provided?
% Or should it be transiently added when editing options??
% Reason for asking: Might become messy when it is executed during batch...



    % TODO:
    % [ ] Edit options method, or use optionsmanager?
   
    properties (Dependent)
        Options
    end
    
    properties (Access = protected)
        Options_
    end
    
    properties (Access = protected)
        OptionsManager nansen.manage.OptionsManager
    end
    
    methods (Static, Abstract)
        options = getDefaultOptions()
    end
    
    methods % Constructor
        
        function obj = HasOptions(options, optionsName)
            
            % Todo: What about options name?
            
            if nargin == 0 || isempty(options)
                obj.assignOptionsManager()
            elseif nargin == 1
                obj.Options_ = options;
            end
            
        end
        
    end
    
    methods
        function assignOptionsManager(obj, className)
            if nargin < 2
                className = class(obj);
            end
            obj.OptionsManager = nansen.OptionsManager(className);
        end
        
        function editOptions(obj)
            [~, optsStruct] = obj.OptionsManager.editOptions('Custom', obj.Options);
            obj.Options_ = optsStruct;
        end
    end
    
    methods
        
        function set.Options(obj, opts)
            obj.Options_ = opts;
        end
        
        function opts = get.Options(obj)
            if ~isempty(obj.Options_)
                opts = obj.Options_;
            elseif ~isempty(obj.OptionsManager)
                opts = obj.OptionsManager.Options;
            end
        end
        
    end
    
    methods (Static, Sealed, Access = protected)
        
        function options = getSuperClassOptions(className)
        %getSuperClassOptions Get default options from all superclasses   
            if nargin < 1
                className = mfilename('class');
            end
            
            mc = meta.class.fromName(className);
            superClassNames = {mc.SuperclassList.Name};
            
            numSuperClasses = numel(superClassNames);
            options = {};
            
            for i = 1:numSuperClasses
                iClassName = superClassNames{i};
                getOptsFcn = str2func([iClassName, '.getDefaultOptions']);
                try
                    options = [options, getOptsFcn()];
                end
                
                options = [options, nansen.mixin.HasOptions.getSuperClassOptions(iClassName)];
                
            end

        end
        
        function options = combineOptions(options, varargin)
            for i = 1:numel(varargin)

                fields = fieldnames(varargin{i});

                for j = 1:numel(fields)
                    options.(fields{j}) = varargin{i}.(fields{j});
                end
            end
        end
        
    end
    


end