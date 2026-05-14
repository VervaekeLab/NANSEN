function varargout = openRoiClassifier(sessionObject, varargin)
%Open the ROI classifier for a selected ROI variable.
%
%Use this when:
%- You want to manually label ROIs as cells, non-cells, or other configured
%  classes.
%- You have one or more ROI variables available for the selected session.
%
%What happens:
%- NANSEN asks which ROI variable to classify.
%- If needed, the ROI data are loaded through the ROI file adapter so the
%  classifier receives a roiGroup.
%- If ROI images are missing, the motion-corrected stack is passed in so
%  the classifier can show image context.
%
%Outputs:
%- Classification edits are handled by the ROI classifier app for the
%  selected ROI file.

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
    params = utility.parsenvpairs(params, 1, varargin);

% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Implementation of the session method.

    sessionData = nansen.session.SessionData( sessionObject );
    sessionData.updateDataVariables()

    varName = sessionData.uiSelectVariableName('roiArray', 'single');

    if ~isempty(varName)
        roiData = sessionData.(varName{1});
    else
        return
    end

    if ~isa(roiData, 'roimanager.roiGroup')
        roiGroup = getRoiGroup(sessionObject, roiData, varName{1});
    else
        roiGroup = roiData;
    end

    % Todo: Need to adapt to multichannel roigroups. The best would be to
    % transform roigroup into a 1d thing. See composite roi group.

    if numel(roiGroup) > 1
        roiGroup = roimanager.CompositeRoiGroup(roiGroup);
    end

    try
        if isempty(roiGroup.roiImages)
            imageStack = sessionData.TwoPhotonSeries_Corrected;
            hClassifier = roiclassifier.openRoiClassifier(roiGroup, imageStack, params);
        else
            hClassifier = roiclassifier.openRoiClassifier(roiGroup, params);
        end

        hClassifier.dataFilePath = sessionObject.getDataFilePath(varName{1});

        % Todo: uiwait and then retrieve results and save when closing?

    catch ME
        throw(ME)
    end
end

function S = getDefaultParameters()

    S = struct();
    S.RoiSelectedCallbackFunction = ''; % Optional callback used when an ROI is selected.
end

function roiGroup = getRoiGroup(sessionObject, roiArray, roiVariableName)

        roiGroup = []; %#ok<NASGU>

        filePath = sessionObject.getDataFilePath(roiVariableName);
        roiFileAdapter = nansen.dataio.fileadapter.roi.RoiGroup(filePath);
        roiGroup = roiFileAdapter.load();

        % Todo: Create roi images and stats if they dont exist...
end
