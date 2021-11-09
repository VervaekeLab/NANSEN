classdef ChunkProcessor < uim.handle %& matlab.mixin.Heterogenous
     
% Super class for image stack method.
%
%   Many methods have things in common.
%
%       1) need to set some options.
%       2) need to load and process data in chunks
%       3) need to do something per chunk / or per frame
%       4) need to save some output
%        
%  Another feature that can be developed: Use for processing different 
%  methods on each chunk, similar to mapreduce... Requires:
%       Inherit from matlab.mixin.Heterogenous
%       A loop within runMethod to loop over an arry of obj
%       Some system to make sure the sourceStack of all objs are the same


% - - - - - - - - - - TODO - - - - - - - - - - - - - - - - - - -
%     [ ] Property with name of which stack to use. Would be good practice
%     for methods that would always work on the same stack, but not for
%     methods that works on any stack....


% - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - 

    properties (Access = protected)
        SourceStack % The image stack to use as source
        TargetStack % The image stack to use as target (optional)
    end
    
    properties (Access = public)
        DataPreProcessFcn   = []    % Function to apply on image data when loading
        DataPreProcessOpts  = []    % Options to use when preprocessing image data
        DataPostProcessFcn  = []    % Function to apply on image data when saving
        DataPostProcessOpts = []    % Options to use when postprocessing image data
    end

    properties % Options
        frameInterval = [] % if empty, process all frames
        numFramesPerPart = 1000;            
        partsToProcess = 'all';
        redoPartIfFinished = false;
    end
    
    
% - - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - 

    methods (Static)
        function S = getDefaultOptions()
            S.numFramesPerPart = 1000;            
            S.partsToProcess = 'all';
            S.redoPartIfFinished = false;
        end
    end
    
    methods (Abstract, Access = protected)
        Y = processPart(obj, Y, iIndices);
    end

    methods % Constructor
        
        function obj = ChunkProcessor(varargin)
            
            obj.initialize()
            
            obj.processChunks()
            
            obj.finish()
            
        end
        
        function runMethod(obj)
            
        end
    end
    
    methods (Access = protected) % Subroutines

        function openSourceStack(~)
            % Subclass may implement
        end
        
        function openTargetStack(~)
            % Subclass may implement
        end
        
        function getPartsToProcess(~)
            % Subclass may implement
        end
        
        function isPartFinished(~)
            % Subclass may implement
        end
        
        function initialize(obj)
            fprintf('Initializing %s', class(obj))
            % Subclass may implement
            
            obj.onInitialization()
        end
        
        function processChunks(obj)
            
            N = obj.numFramesPerPart;
            [IND, numParts] = obj.SourceStack.getChunkedFrameIndices(N);
            
            
            % Loop through 
            for iPart = 1:numParts
                
                iIndices = IND{iPart};
                
                % Load data Todo: Make method. Two photon session method?
                Y = obj.SourceStack.getFrameSet(iIndices);

                if ~isempty(obj.DataPreProcessFcn)
                    Y = obj.DataPreProcessFcn(Y, obj.DataPreProcessOpts);
                end
                
                Y = obj.processPart(Y, iIndices);
                
                if ~isempty(Y) && ~isempty(obj.TargetStack)
                    if ~isempty(obj.DataPostProcessFcn)
                        Y = obj.DataPostProcessFcn(Y, obj.DataPostProcessOpts);
                    end
                    
                    obj.TargetStack.writeFrameSet(iIndices, Y)
                    
                end
                
            end
            
        end
        
        function finish(~)
            % Subclass may implement
        end
        
    end

end 