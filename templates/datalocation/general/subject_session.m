function S = subject_session()
%SUBJECT_SESSION Template for datalocation organized by subject and session
%
%   S = subject_session() returns a template for a sciscan datalocation 

    import nansen.config.dloc.DataLocationModel
    
    S = struct();
    S.Name = 'Subject-Session';
    S.DataType = 'Processed';
    
  % % Assign subfolder structure 
    S.SubfolderStructure = DataLocationModel.getDefaultSubfolderStructure;
    
    S.SubfolderStructure(1).Type = 'Animal';
    S.SubfolderStructure(2).Type = 'Session';

  % % No metadata specification
    S.MetaDataDef = DataLocationModel.getDefaultMetadataStructure;
end

