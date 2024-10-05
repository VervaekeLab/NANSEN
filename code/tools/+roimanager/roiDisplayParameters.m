function [P, V] = roiDisplayParameters()

    % - - - - - - - - Specify parameters and default values - - - - - - - -
    
    % Names                       Values (default)      Description
    P                           = struct();             %
    P.showNeuropilMask          = false;                % Flag for displaying the neuropil mask of a roi
    P.showLabels                = false;                % Flag for displaying roi labels
    P.showOutlines              = true;                 % Flag for displaying roi outlines
    P.maskRoiInterior           = false;                % Flag for masking the interior of a roi (replace pixels with their average projections)
    
    P.showByClassification      = 'Show All';
    P.showByClassification_     = {'Show All', 'Show Unclassified', 'Show Accepted', 'Show Rejected', 'Show Unresolved'};

    P.roiColorScheme            = 'None';
    P.roiColorScheme_           = {'None', 'Category', 'Classification'};
    
    P.setCurrentRoiGroup        = 'Group 1';
    P.setCurrentRoiGroup_       = {'Group 1'};
       
    P.showRoiGroups             = 'Show All';
    P.showRoiGroups_            = {'Show All', 'Show Group 1'};

    P.roiThumbnailSize          = [21, 21];

    % - - - - Specify validation/assertion test for each parameter - - - -
    
    V                           = struct();
    V.showNeuropilMask          = @(x) assert( islogical(x) && isscalar(x), ...
                                    'Value must be a logical scalar' );
    V.showLabels                = @(x) assert( islogical(x) && isscalar(x), ...
                                    'Value must be a logical scalar' );
                                
end
