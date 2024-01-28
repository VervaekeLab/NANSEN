function S = subject_session()
%SUBJECT_SESSION Template for datalocation organized by subject and session
%
%   S = subject_session() returns a template for a sciscan datalocation 

    import nansen.config.dloc.DataLocationModel
    
    S = struct();
    S.x_type = 'Nansen Data Location Template Specification';
    S.x_version = '1.0.0';

    S.Name = 'Subject-Session';
    S.DataType = 'Processed';
    
  % % Assign subfolder structure 
    S.SubfolderStructure = DataLocationModel.getDefaultSubfolderStructure;
    
    S.SubfolderStructure(1).Type = 'Subject';
    S.SubfolderStructure(2).Type = 'Session';

  % % No metadata specification
    S.MetaDataDef = DataLocationModel.getDefaultMetadataStructure;

    % Export to module:
    targetPath = fullfile(nansen.common.constant.ModuleRootDirectory, ...
        '+nansen', '+module', '+general', '+core', 'resources', 'datalocations');

    fileName = 'subject_session.json';
    savePath = fullfile(targetPath, fileName);
    utility.io.savejson(savePath, S)
end

