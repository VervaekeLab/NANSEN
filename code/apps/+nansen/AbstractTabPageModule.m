classdef AbstractTabPageModule < handle
% AbstractTabPageModule Interface for content of a tab page
%
%   Abstract methods:
%       createComponents

    properties (Abstract, Constant)
        Name
    end

    properties (SetAccess = private)
        Parent
    end

    properties (Access = private) % Internal
        KeypressListener event.listener % Todo?: If module is opened in figure
        ParentSizeChangedListener event.listener
    end

    methods % Constructor
    
        function obj = AbstractTabPageModule(varargin)
        %AbstractTabPageModule - Constructor
        %
        %   Input arguments:
        %       parentHandle - Optional: If the first input is a graphical
        %           container it is assigned to the Parent property and all
        %           components are added to it.
        %       varargin - Optional name value pairs?
            
            obj.parseInputs(varargin)

            obj.createComponents()

            obj.onStartup()

            obj.updateComponentLayout()

            obj.createListeners()
        end
    end

    methods (Access = private)

        function parseInputs(obj, listOfArgs)
            
            if isempty(listOfArgs);    return;    end
            
            if isgraphics(listOfArgs{1})
                obj.Parent = listOfArgs{1};
                listOfArgs = listOfArgs(2:end);
            end

            obj.handleOptionalInputs(listOfArgs)
        end
    end

    methods (Access = private) % Create components and internal elements.
        function createListeners(obj)
            obj.ParentSizeChangedListener = listener(obj.Parent, ...
                'SizeChanged', @obj.onParentSizeChanged);
        end
    end

    methods (Access = private) % Internal callback methods.
        function onParentSizeChanged(obj, src, evt)
            obj.updateComponentLayout()
        end
    end

    methods (Abstract, Access = protected) % Required subclass methods
        
        createComponents(obj)

    end
    
    methods (Access = protected) % Optional subclass methods
        
        function onStartup(obj) %#ok<*MANU>
            % Subclasses may override.
        end

        function handleOptionalInputs(obj, listOfInputs) %#ok<*INUSD>
            % Subclasses may override.
        end

        function updateComponentLayout(obj)
            % Subclasses may override.
        end
    end

    methods (Access = {?nansen.App, ?nansen.AbstractTabPageModule})
        
        function wasCaptured = onKeyPressed(obj, ~, evt) %#ok<STOUT>
            % Subclasses may override.
            wasCaptured = false;
        end
    end
end
