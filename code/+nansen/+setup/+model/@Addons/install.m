
% This is a toobox file:
% Note: This script show example code for installing a matlab
% toolbox (mltbx) file or unzipping a zipped git download.

% UI Widgets toolbox

matlabCentralUrl = 'https://se.mathworks.com/matlabcentral/mlc-downloads/';


% Todo: create add-on struct.
% Fields: Name, Source, URL, filename... + SOme function to check if
% toolbox is installed.


toolboxUrl = struct();
toolboxUrl.Widgets = '78895307-cc36-4970-8b66-0697da8f9352/4ae5c052-7f28-4fcf-9383-0d6ce4622d22/packages/mltbx';
toolboxUrl.GuiLayout = 'e5af5a78-4a80-11e4-9553-005056977bd0/2.3.5/packages/mltbx';


% Todo: Assemble a save path to save temp downloaded files.
savePath = fullfile(getDesktop, 'test_download', 'test');

% Download files
websave(savePath, toolboxPath)


if isToolbox
    newAddon = matlab.addons.install(fileName);
    
elseif isGithubRepo
    
    % Unzip the repo file
    fprintf('Unzipping file %s\n', rawSavePathDownload)
    filenames = unzip(rawSavePathDownload, addonFolderPath);
    % cellfun(@disp,filenames,'UniformOutput',false) 
    
    % Add to path
    
end

