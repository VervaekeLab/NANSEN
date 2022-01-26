function S = getDefaultItem()
%getDefaultItem Return a list of default datalocation items

% Name              : Name of data location
% RootPath          : Root path where data of this type is present (Cell array with two elements)
% ExamplePath       : Example path to a data/session folder
% DataSubfolders    : List of subfolders present in data/session folders (Not implemented yet)
%
% SubfolderStructure : A struct array of info about folder hierarchy going
% for the rood directoty to a data directory
% SubfolderStructure.Name       : Name of a subfolder on specific level
% SubfolderStructure.Type       : Type of a subfolder on specific level (i.e animal, date, session etc)
% SubfolderStructure.Expression : String expression used for detecting folders on this level
% SubfolderStructure.IgnoreList : List of strings to ignore...

    i = 1;
    S(i) = nansen.setup.model.DataLocations.getEmptyItem();
    S(i).Name = 'Rawdata';
    S(i).RootPath = {'', ''};
    S(i).ExamplePath = '';
    S(i).DataSubfolders = {};
    
    %S(i).SubfolderStructure = struct('Name', {}, 'Type', {}, 'Expression', {}, 'IgnoreList', {});
    S(i).SubfolderStructure(1).Name = '';
    S(i).SubfolderStructure(1).Type = '';
    S(i).SubfolderStructure(1).Expression = '';
    S(i).SubfolderStructure(1).IgnoreList = {};
    
    i = i + 1;
    S(i) = nansen.setup.model.DataLocations.getEmptyItem();
    S(i).Name = 'Processed';
    S(i).RootPath = {'', ''};
    S(i).ExamplePath = '';
    S(i).DataSubfolders = {};

    S(i).SubfolderStructure(1).Type = 'Animal';
    S(i).SubfolderStructure(2).Type = 'Session';
    
end