function [S, P] = getDefaultItem()
%getDefaultItem Return a list of default datalocation items

% Name              : Name of data location
% RootPath          : Root path where data of this type is present (Cell array with two elements)
% ExamplePath       : Example path to a data/session folder
% DataSubfolders    : List of subfolders present in data/session folders (Not implemented yet)
%
% SubfolderStructure : A struct array of info about folder hierarchy going
% for the rood directory to a data directory
% SubfolderStructure.Name       : Name of a subfolder on specific level
% SubfolderStructure.Type       : Type of a subfolder on specific level (i.e subject, date, session etc)
% SubfolderStructure.Expression : String expression used for detecting folders on this level
% SubfolderStructure.IgnoreList : List of strings to ignore...

    i = 1;
    S(i) = nansen.config.dloc.DataLocationModel.getBlankItem();
    S(i).Name = 'Rawdata';
    S(i).Type = nansen.config.dloc.DataLocationType('recorded');
    %S(i).RootPath = {'', ''};
    %S(i).ExamplePath = '';
    %S(i).DataSubfolders = {};
    
    %S(i).SubfolderStructure = struct('Name', {}, 'Type', {}, 'Expression', {}, 'IgnoreList', {});
    S(i).SubfolderStructure(1).Name = '';
    S(i).SubfolderStructure(1).Type = '';
    S(i).SubfolderStructure(1).Expression = '';
    S(i).SubfolderStructure(1).IgnoreList = {};
    
    i = i + 1;
    S(i) = nansen.config.dloc.DataLocationModel.getBlankItem();
    S(i).Name = 'Processed';
    S(i).Type = nansen.config.dloc.DataLocationType('processed');
    %S(i).RootPath = {'', ''};
    %S(i).ExamplePath = '';
    %S(i).DataSubfolders = {};

    S(i).SubfolderStructure(1).Type = 'Subject';
    S(i).SubfolderStructure(2).Type = 'Session';
    
    P.DefaultDataLocation = 'Processed';
    
end
