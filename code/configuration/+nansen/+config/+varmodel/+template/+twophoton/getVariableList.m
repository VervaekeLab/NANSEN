function variableList = getVariableList()

    % Initialize struct array with default fields.
    variableList = nansen.config.varmodel.VariableModel.getBlankItem();

    % Original (raw) two photon recording
    variableList(1).VariableName = 'TwoPhotonSeries_Original';
    variableList(1).IsDefaultVariable = true;

    % Corrected (motion-corrected) two photon recording
    variableList(2).VariableName = 'TwoPhotonSeries_Corrected';
    variableList(2).IsDefaultVariable = true;
    variableList(2).FileNameExpression = 'two_photon_corrected';
    variableList(2).DataLocation = 'Processed';
    variableList(2).FileType = '.raw';
    variableList(2).Subfolder = 'image_registration';

    % Roi masks for corrected two photon series
    variableList(3).VariableName = 'RoiMasks';
    variableList(3).IsDefaultVariable = false;
    variableList(3).FileNameExpression = 'roi_masks';
    variableList(3).DataLocation = 'Processed';
    variableList(3).FileType = '.mat';

%             variableList(4).VariableName = 'RoiResponses_Original';
%             variableList(5).VariableName = 'RoiResponses_DfOverF';



end
            