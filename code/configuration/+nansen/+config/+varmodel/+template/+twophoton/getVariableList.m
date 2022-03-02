function variableList = getVariableList()

    % Initialize struct array with default fields.
    variableList = nansen.config.varmodel.VariableModel.getBlankItem();
    
    i = 1;
    % Original (raw) two photon recording
    variableList(i).VariableName = 'TwoPhotonSeries_Original';
    variableList(i).IsDefaultVariable = true;

    i = i+1;
    % Corrected (motion-corrected) two photon recording
    variableList(i).VariableName = 'TwoPhotonSeries_Corrected';
    variableList(i).IsDefaultVariable = true;
    variableList(i).DataLocation = '';
    variableList(i).Subfolder = 'image_registration';
    variableList(i).FileNameExpression = 'two_photon_corrected';
    variableList(i).FileType = '.raw';

    i = i+1;
    % Roi masks for corrected two photon series
    variableList(i).VariableName = 'RoiMasks';
    variableList(i).IsDefaultVariable = false;
    variableList(i).DataLocation = '';
    variableList(i).Subfolder = 'roi_data';
    variableList(i).FileNameExpression = 'roi_masks';
    variableList(i).FileType = '.mat';
    
    i = i+1;
    % Curated roi masks for corrected two photon series
    variableList(i).VariableName = 'RoiMasksCurated';
    variableList(i).IsDefaultVariable = false;
    variableList(i).DataLocation = '';
    variableList(i).Subfolder = 'roi_data';
    variableList(i).FileNameExpression = 'roi_masks_curated';
    variableList(i).FileType = '.mat';
    
    i = i+1;
    % Array of roi objects
    variableList(i).VariableName = 'RoiArray';
    variableList(i).IsDefaultVariable = false;
    variableList(i).DataLocation = '';
    variableList(i).Subfolder = 'roi_data';
    variableList(i).FileNameExpression = 'roi_array';
    variableList(i).FileType = '.mat';
    
    i = i+1;
    % Curated array of roi objects
    variableList(i).VariableName = 'RoiArrayCurated';
    variableList(i).IsDefaultVariable = false;
    variableList(i).DataLocation = '';
    variableList(i).Subfolder = 'roi_data';
    variableList(i).FileNameExpression = 'roi_array_curated';
    variableList(i).FileType = '.mat';
    
    i = i+1;
    % RoiResponseSeries
    variableList(i).VariableName = 'RoiResponseSeries_Original';
    variableList(i).IsDefaultVariable = false;
    variableList(i).DataLocation = '';
    variableList(i).Subfolder = 'roi_data';
    variableList(i).FileNameExpression = 'roiresponse_original';
    variableList(i).FileType = '.mat';
        
    i = i+1;
    % RoiResponseSeries Dff
    variableList(i).VariableName = 'RoiResponseSeries_Dff';
    variableList(i).IsDefaultVariable = false;
    variableList(i).DataLocation = '';
    variableList(i).Subfolder = 'roi_data';
    variableList(i).FileNameExpression = 'roiresponse_dff';
    variableList(i).FileType = '.mat';
    
    i = i+1;
    % RoiResponseSeries Deconvolved
    variableList(i).VariableName = 'RoiResponseSeries_Deconvolved';
    variableList(i).IsDefaultVariable = false;
    variableList(i).DataLocation = '';
    variableList(i).Subfolder = 'roi_data';
    variableList(i).FileNameExpression = 'roiresponse_deconvolved';
    variableList(i).FileType = '.mat';
    

end
            