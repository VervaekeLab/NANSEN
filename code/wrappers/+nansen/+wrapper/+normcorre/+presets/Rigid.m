classdef Rigid < nansen.wrapper.normcorre.Options
%Rigid Preconfigured options for rigid motion correction using normcorre

    properties (Constant)
        Name = 'Rigid'
        Description = 'Options for rigid correction'
    end
    
    methods (Static)
        
        function S = getOptions()
            
            S = getOptions@nansen.wrapper.normcorre.Options();

            % Todo: Make sure gridsize can not be changed for rigid...
            S.Configuration.numRows         = 1;                    % Size of non-overlapping portion of each patch in the grid (y-direction)
            S.Configuration.numCols         = 1;                    % Size of non-overlapping portion of each patch in the grid (x-direction)
            S.Configuration.patchOverlap    = [32,32,16];           % Size of overlapping region in each direction before upsampling
            S.Configuration.gridUpsampling  = [4 4 1];              % Upsampling factor for smoothing and refinement of motion field

            S.Template.updateTemplate       = true;
            S.Template.initialBatchSize     = 100;
            S.Template.binWidth             = 50;
                        
        end
        
        % Todo: implement this with optionsmanager/structeditor
        function newValue = validateOptions(name, value)
            
            switch name
                case {'numRows', 'numCols'}
                    newValue = 1;
                otherwise
                    newValue = value;
            end
            
        end
    end
    
end