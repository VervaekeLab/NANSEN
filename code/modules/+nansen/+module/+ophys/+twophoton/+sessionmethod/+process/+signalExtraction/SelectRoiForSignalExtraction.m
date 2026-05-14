function varargout = SelectRoiForSignalExtraction(sessionObject, varargin)
%Choose which ROI set should be used for signal extraction.
%
%Use this when:
%- A session has multiple ROI variables, for example automatic detections
%  and manually curated ROIs.
%- You want `Extract Signals` to use a specific ROI set.
%
%What happens:
%- NANSEN asks which ROI variable to use.
%- The selected ROI group can optionally be cleaned by removing ROIs with
%  pixels outside the FOV boundary.
%- The selected ROI group is saved as the default `RoiArray`.
%
%Outputs:
%- `RoiArray`: the ROI set that signal-extraction methods will use by
%  default.

% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Create a struct of default parameters (if applicable) and specify one or
% more attributes (see nansen.session.SessionMethod.setAttributes) for
% details.

    % Get struct of parameters from local function
    params = getDefaultParameters();

    % Create a cell array with attribute keywords
    ATTRIBUTES = {'serial', 'unqueueable'};

% % % % % % % % % % % % % DEFAULT CODE BLOCK % % % % % % % % % % % % % %
% - - - - - - - - - - Please do not edit this part - - - - - - - - - - -

    % Create a struct with "attributes" using a predefined pattern
    import nansen.session.SessionMethod
    fcnAttributes = SessionMethod.setAttributes(params, ATTRIBUTES{:});

    if ~nargin && nargout > 0
        varargout = {fcnAttributes};   return
    end

    % Parse name-value pairs from function input.
    params = utility.parsenvpairs(params, [], varargin);

% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Implementation of the session method.

    sessionData = nansen.session.SessionData( sessionObject );
    sessionData.updateDataVariables()

    varName = sessionData.uiSelectVariableName('RoiArray', 'single');

    if ~isempty(varName)
        roiGroup = sessionData.(varName{1});
    else
        return
    end

    if params.deleteRoisOutsideTheBorders

        for jGroup = 1:numel(roiGroup)
            outside = false(roiGroup(jGroup).roiCount, 1);

            for iRoi = 1:1:roiGroup(jGroup).roiCount
                outside(iRoi) = hasPixelsOutsideImage(...
                    roiGroup(jGroup).roiArray(iRoi), ...
                    roiGroup(jGroup).FovImageSize);
            end

            % outside = roiArray.roiArray.isOutsideImage(); % alternative
            % method but this checks the center

            roiGroup(jGroup).removeRois(find(outside))
        end
    end

    sessionObject.saveData('RoiArray', roiGroup)

    message = sprintf('Selected rois "%s" for signal extraction', varName{1});
    title = 'RoI Selection Applied';
    msgbox(message, title)
end

function isOutside = hasPixelsOutsideImage(roi, fovSize)
    xOut = any(roi.coordinates(:,1) < 1) || any(roi.coordinates(:,1) > fovSize(2));
    yOut = any(roi.coordinates(:,2) < 1) || any(roi.coordinates(:,2) > fovSize(1));
    isOutside = xOut || yOut;
end

function S = getDefaultParameters()
    S = struct();
    S.deleteRoisOutsideTheBorders = true; % Remove ROIs with pixels outside the FOV before saving RoiArray.
end
