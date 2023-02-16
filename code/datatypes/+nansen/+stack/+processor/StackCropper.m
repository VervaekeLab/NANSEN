classdef StackCropper < nansen.stack.ImageStackProcessor
%StackCropper Class for cropping an ImageStack

    properties
        NewSize (1,2) double
    end
    
    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'Crop Stack'
        IsManual = false        % Does method require manual supervision?
        IsQueueable = true      % Can method be added to a queue?
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager(mfilename('class'))
    end

    properties (Constant, Hidden)
        DATA_SUBFOLDER = ''	% defined in nansen.DataMethod
        VARIABLE_PREFIX	= '' % defined in nansen.DataMethod
    end 

    methods (Static)
        
        function S = getDefaultOptions()
        % Get default options for the temporal downsampler    
            S.Cropping.NewSize    = [512, 512];
            className = mfilename('class');
            superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
            S = nansen.mixin.HasOptions.combineOptions(S, superOptions{:});            
        end
        
    end
    methods % Constructor
        
        function obj = StackCropper(sourceStack, newSize, varargin)

            obj@nansen.stack.ImageStackProcessor(sourceStack, varargin{:})
            
            obj.NewSize = newSize;

            if ~nargout
                obj.runMethod()
                clear obj
            end
            
        end

    end

    methods (Access = protected) % Overide ImageStackProcessor methods
        function onInitialization(obj)
            
            % Create output filepath
            [~, sourceName] = fileparts( obj.SourceStack.FileName );
            targetName = strcat(sourceName, '_cropped');
            
            targetFilepath = strrep(  obj.SourceStack.FileName, sourceName, targetName ); 

            % Get new size
            stackSize = size( obj.SourceStack.Data );
            stackSize(1:2) = obj.NewSize;

            % Get data type from source stack
            dataTypeOut = obj.SourceStack.DataType;

            obj.openTargetStack(targetFilepath, stackSize, dataTypeOut, ...
                'DataDimensionArrangement', obj.SourceStack.Data.StackDimensionArrangement);
        end
        
    end

    methods (Access = protected) % todo: make public??
        function [Y, results] = processPart(obj, Y, ~)

            if size(Y, 1) > obj.NewSize(1)
                numLinesToCrop = size(Y, 1) - obj.NewSize(1);
                ind = repmat({':'}, 1, ndims(Y));
                ind{1} = numLinesToCrop+1 : size(Y, 1);
                Y = Y(ind{:});
            end

            if size(Y, 2) > obj.NewSize(2)
                Y = stack.reshape.imcropcenter(Y, obj.NewSize);
            end

            results = [];
        end
    end
end