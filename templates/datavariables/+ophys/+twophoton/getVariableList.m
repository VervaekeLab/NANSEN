function variableList = getVariableList()

    NUM_VARS = 10; % Should be updated if variables are added.

    % Initialize struct array with default fields.
    variableList = nansen.config.varmodel.VariableModel.getBlankItem();
    [variableList(1:NUM_VARS)] = deal(variableList);
    
    i = 1;
    % Original (raw) two photon recording
    variableList(i).VariableName = 'TwoPhotonSeries_Original';
    variableList(i).IsDefaultVariable = true;

    i = i+1;
    % Corrected (motion-corrected) two photon recording
    variableList(i).VariableName = 'TwoPhotonSeries_Corrected';
    variableList(i).IsDefaultVariable = true;
    variableList(i).DataLocation = 'DEFAULT';
    variableList(i).Subfolder = 'image_registration';
    variableList(i).FileNameExpression = 'two_photon_corrected';
    variableList(i).FileType = '.raw';

    i = i+1;
    % Roi masks for corrected two photon series
    variableList(i).VariableName = 'RoiMasks';
    variableList(i).IsDefaultVariable = true;
    variableList(i).DataLocation = 'DEFAULT';
    variableList(i).Subfolder = 'roi_data';
    variableList(i).FileNameExpression = 'roi_masks';
    variableList(i).FileType = '.mat';
    
    i = i+1;
    % Array of roi objects
    variableList(i).VariableName = 'RoiArray';
    variableList(i).IsDefaultVariable = true;
    variableList(i).DataLocation = 'DEFAULT';
    variableList(i).Subfolder = 'roi_data';
    variableList(i).FileNameExpression = 'roi_array';
    variableList(i).FileType = '.mat';
    
    i = i+1;
    % Curated array of roi objects
    variableList(i).VariableName = 'RoiArrayCurated';
    variableList(i).IsDefaultVariable = true;
    variableList(i).DataLocation = 'DEFAULT';
    variableList(i).Subfolder = 'roi_data';
    variableList(i).FileNameExpression = 'roi_array_curated';
    variableList(i).FileType = '.mat';
    
   % Roi signals
   % - - - - - - 
    i = i+1;
    variableList(i).VariableName = 'RoiSignals_MeanF';
    variableList(i).Alias = 'fRoi';
    variableList(i).IsDefaultVariable = true;
    variableList(i).DataLocation = 'DEFAULT';
    variableList(i).Subfolder = 'roisignals';
    variableList(i).FileNameExpression = 'roisignals';
    variableList(i).FileType = '.mat';
    variableList(i).FileAdapter = 'RoiSignalArray';
    
    i = i+1; 
    variableList(i).VariableName = 'RoiSignals_NeuropilF';
    variableList(i).Alias = 'fNeuropil';
    variableList(i).IsDefaultVariable = true;
    variableList(i).DataLocation = 'DEFAULT';
    variableList(i).Subfolder = 'roisignals';
    variableList(i).FileNameExpression = 'roisignals';
    variableList(i).FileType = '.mat';
    variableList(i).FileAdapter = 'RoiSignalArray';
    
    i = i+1;
    variableList(i).VariableName = 'RoiSignals_Dff';
    variableList(i).Alias = 'dff';
    variableList(i).IsDefaultVariable = true;
    variableList(i).DataLocation = 'DEFAULT';
    variableList(i).Subfolder = 'roisignals';
    variableList(i).FileNameExpression = 'roisignals';
    variableList(i).FileType = '.mat';
    variableList(i).FileAdapter = 'RoiSignalArray';
    
    i = i+1; 
    variableList(i).VariableName = 'RoiSignals_Denoised';
    variableList(i).Alias = 'denoised';
    variableList(i).IsDefaultVariable = true;
    variableList(i).DataLocation = 'DEFAULT';
    variableList(i).Subfolder = 'roisignals';
    variableList(i).FileNameExpression = 'roisignals';
    variableList(i).FileType = '.mat';
    variableList(i).FileAdapter = 'RoiSignalArray';
    
    i = i+1; 
    variableList(i).VariableName = 'RoiSignals_Deconvolved';
    variableList(i).Alias = 'deconvolved';
    variableList(i).IsDefaultVariable = true;
    variableList(i).DataLocation = 'DEFAULT';
    variableList(i).Subfolder = 'roisignals';
    variableList(i).FileNameExpression = 'roisignals';
    variableList(i).FileType = '.mat';
    variableList(i).FileAdapter = 'RoiSignalArray';
    
end
            