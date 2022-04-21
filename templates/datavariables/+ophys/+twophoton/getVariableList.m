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
    variableList(i).FileAdapter = 'ImageStack';
    
    i = i+1;
    % Array of roi objects
    variableList(i).VariableName = 'Rois';
    variableList(i).IsDefaultVariable = true;
    variableList(i).DataLocation = 'DEFAULT';
    variableList(i).Subfolder = 'roi_data';
    variableList(i).FileNameExpression = 'rois';
    variableList(i).FileType = '.mat';
    variableList(i).FileAdapter = 'RoiGroup';
    
    i = i+1;
    % Curated array of roi objects
    variableList(i).VariableName = 'RoisCurated';
    variableList(i).IsDefaultVariable = true;
    variableList(i).DataLocation = 'DEFAULT';
    variableList(i).Subfolder = 'roi_data';
    variableList(i).FileNameExpression = 'rois_curated';
    variableList(i).FileType = '.mat';
    variableList(i).FileAdapter = 'RoiGroup';
    
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
            