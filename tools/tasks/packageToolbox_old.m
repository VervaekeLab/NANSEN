function packageToolbox(versionNumber)
% Script for packaging a toolbox (mltbx)
%
%   Example:
%       packageToolbox('0.9.2')

    arguments
        versionNumber (1,1) string
    end

    pattern = '^\d+\.\d+\.\d+$|^\d+\.\d+\.\d+\.\d+$';
    assert( ~isempty( regexp(versionNumber, pattern, 'once')), ...
        'Invalid version number')

    nansen.internal.utility.updateVersionInContents(versionNumber)

    % This should be the same across versions:
    identifier = "07b2cd84-23b5-43a5-a61b-a5de9d19687a"; 
    rootFolder = fileparts(fileparts(mfilename("fullpath")));
    toolboxFolder = fullfile("..", "code");
    opts = matlab.addons.toolbox.ToolboxOptions(toolboxFolder, identifier);
    
    toIgnore = contains(opts.ToolboxFiles, '_dev');
    opts.ToolboxFiles = opts.ToolboxFiles(~toIgnore);
    
    opts.AuthorName = 'Eivind Hennestad';
    opts.AuthorEmail = 'eivihe@uio.no';
    
    opts.ToolboxName = "NANSEN - Neuro Analysis Software Ensemble";
    opts.Summary = "A collection of apps and modules for processing, analysis and visualization of two-photon imaging data.";
    opts.ToolboxVersion = versionNumber;
    opts.ToolboxImageFile = fullfile(rootFolder, 'resources', 'images', 'toolbox_image.png');
    
    codeFolders = strsplit(genpath(toolboxFolder), pathsep);
    opts.ToolboxMatlabPath = codeFolders( cellfun(@(c) ~isempty(c), codeFolders));
    
    opts.SupportedPlatforms.Win64 = true;
    opts.SupportedPlatforms.Maci64 = true;
    opts.SupportedPlatforms.Glnxa64 = true;
    opts.SupportedPlatforms.MatlabOnline = true;
    
    opts.MinimumMatlabRelease = "R2019a";
    opts.MaximumMatlabRelease = "";
    
    opts.RequiredAddons = ...
        struct("Name","Widgets Toolbox", ...
               "Identifier","b0bebf59-856a-4068-9d9c-0ed8968ac9e6", ...
               "EarliestVersion","1.3.330", ...
               "LatestVersion","1.3.330", ...
               "DownloadURL","");
    
    loadPath = fullfile( nansen.rootpath, 'resources', 'dependencies', 'required_addons.json' );
    S = jsondecode(fileread(loadPath));
    
    for i = 1:numel(S)
    opts.RequiredAddons(end+1) = ...
        struct("Name",string(S(i).FullName), ...
               "Identifier",string(S(i).FileExchangeUuid), ...
               "EarliestVersion","earliest", ...
               "LatestVersion","latest", ...
               "DownloadURL","");
    end
    
    versionNumber = strrep(opts.ToolboxVersion, '.', '_');
    opts.OutputFile = fullfile(rootFolder, "releases", sprintf("NANSEN_v%s", versionNumber));
    if ~isfolder( fullfile(rootFolder, "releases") ); mkdir(fullfile(rootFolder, "releases")); end
    matlab.addons.toolbox.packageToolbox(opts);
end