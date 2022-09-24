classdef GObjectRecycler < uiw.mixin.AssignPVPairs
%GObjectRecycler Class for recycling graphical object handles of an axes
%
%   The class will cache graphical objects internally, and if cached 
%   objects are available, they will be provided when asked for. If no 
%   objects are available, new objects will be created. If an app needs to 
%   temporarily discard objects, instead of deleting them, the app can use 
%   the recycle method, which resets the graphical object handles and 
%   places them back in the cache.
%
%   Getting cached graphical objects are faster than creating new objects
%   and therefore an app can more flexibly and efficiently scale up and 
%   down the number of objects that are displayed, as well as "replace" 
%   them when needed.

    % Todo: 
    %   [ ] Setting Visible and HandleVisibility has a small overhead.
    %       Necessary? Alternatively, make it more specific.

    properties % Properties that will be defaults for the handles
        HitTest = 'off'
        PickableParts = 'none'
    end
    
    properties 
        CacheSize = inf;    % Not implemented yet
        BlockSize = 10;     % How many new handles to create if no handles are available
    end
    
    properties (SetAccess = immutable, GetAccess = protected)
        ParentAxes
    end

    properties (Dependent, Access = protected)
        NumAvailableObjects
    end

    properties (Access = private)
        GObjects = gobjects(0)
        GObjectPropertyNames
    end
    

    methods (Abstract, Access = protected)
        h = createNewHandles(obj, n)
        h = resetHandleData(obj, h)
    end
    
    methods % Constructor

        function obj = GObjectRecycler(hAxes, varargin)
            obj = obj@uiw.mixin.AssignPVPairs();
            obj.ParentAxes = hAxes;
            obj.assignPVPairs(varargin{:})
        end

        function delete(obj)
            delete(obj.GObjects)
        end

    end
    
    methods % Set/get
        
        function n = get.NumAvailableObjects(obj) 
            n = numel(obj.GObjects);
        end
        
    end

    methods 

        function recycle(obj, h)
            
            if isrow(h); h = transpose(h); end

            h = obj.resetHandleData(h);
            set(h, 'Visible', 'off');
            set(h, 'HandleVisibility', 'off')
            obj.GObjects = cat(1, obj.GObjects, h);
        end

    end

    methods (Access = protected)

        function h = getGobjects(obj, n)
            
            if n > obj.NumAvailableObjects
                numRequired = n - obj.NumAvailableObjects;
                numToCreate = ceil( numRequired ./ obj.BlockSize ) .* obj.BlockSize;
                
                h = obj.createNewHandles(numToCreate);
                set(h, 'Visible', 'off', 'HandleVisibility', 'off')

                obj.GObjects = cat(1, obj.GObjects, h);

            end
            
            h = obj.GObjects(1:n);
            obj.GObjects(1:n) = [];

            set(h, 'HandleVisibility', 'on')
            set(h, 'Visible', 'on'); % Turn visibility on.
        end
        
        function nvPairs = getPropertiesAsNameValuePairs(obj)
            
            if isempty(obj.GObjectPropertyNames)
                propertyNames = properties(obj);
                propertyNames = setdiff(propertyNames, ...
                    {'CacheSize', 'BlockSize'});
                obj.GObjectPropertyNames = propertyNames;
            else
                propertyNames = obj.GObjectPropertyNames;
            end
            
            propertyValues = cell(1, numel(propertyNames));
            for i = 1:numel(propertyNames)
                propertyValues{i} = obj.(propertyNames{i});                
            end

            nvPairs = cat(1, propertyNames', propertyValues);
            nvPairs = transpose( nvPairs(:) ); % Return as row vector
        end

    end

end