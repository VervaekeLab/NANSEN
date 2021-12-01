function S = getAddonList()
%getAddonList Return a list of addons that are needed

% Name          : Name of addon toolbox
% Source        : Where to download addon from (FileExchange or GitHub)
% WebUrl        : Web Url for addon download
% HasSetupFile  : Is there a setup file that should be run?
% SetupName     : Name of setup file if there are any
% FunctionName  : Name of function in repository (used to check if repository already exists on matlab's path)
    
    i = 1;
    S(i).Name = 'GUI Layout Toolbox';
    S(i).Description = '';
    S(i).IsRequired = true;
    S(i).Source = 'FileExchange';
    S(i).WebUrl = 'https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox';
    S(i).DownloadUrl = 'https://se.mathworks.com/matlabcentral/mlc-downloads/downloads/e5af5a78-4a80-11e4-9553-005056977bd0/df368ddb-983a-439f-86cb-04e375916c75/packages/zip';
    S(i).HasSetupFile = false;
    S(i).SetupFileName = '';
    S(i).FunctionName = 'uix.BoxPanel';
    
    i = i + 1;
    S(i).Name = 'Widgets Toolbox';
    S(i).Description = '';
    S(i).IsRequired = true;
    S(i).Source = 'FileExchange';
    S(i).WebUrl = 'https://se.mathworks.com/matlabcentral/fileexchange/66235-widgets-toolbox-compatibility-support?s_tid=srchtitle';
    % Newest version is commented out because it has some bugs. Use a
    % previous version that works.
    %S(i).DownloadUrl = 'https://se.mathworks.com/matlabcentral/mlc-downloads/downloads/b0bebf59-856a-4068-9d9c-0ed8968ac9e6/a22b68d6-b5aa-48cb-87fa-1f4a763578e0/packages/zip';
    S(i).DownloadUrl = 'https://www.mathworks.com/matlabcentral/mlc-downloads/downloads/b0bebf59-856a-4068-9d9c-0ed8968ac9e6/099f0a4d-9837-4e5f-b3df-aa7d4ec9c9c9/packages/zip';
    S(i).HasSetupFile = false;
    S(i).SetupFileName = '';
    S(i).FunctionName = 'uiw.abstract.AppWindow';
    
    i = i + 1;
    S(i).Name = 'CaImAn-Matlab';
    S(i).Description = 'A Computational toolbox for large scale Calcium Imaging data Analysis';
    S(i).IsRequired = false;
    S(i).Source = 'Github';
    S(i).WebUrl = 'https://github.com/flatironinstitute/CaImAn-MATLAB';
    S(i).DownloadUrl = 'https://github.com/flatironinstitute/CaImAn-MATLAB/archive/refs/heads/master.zip';
    S(i).HasSetupFile = false;
    S(i).SetupFileName = '';
    S(i).FunctionName = 'CNMFSetParms';
    
    i = i + 1;
    S(i).Name = 'NoRMCorre';
    S(i).Description = ' Non-Rigid Motion Correction for calcium imaging data';
    S(i).IsRequired = false;
    S(i).Source = 'Github';
    S(i).WebUrl = 'https://github.com/flatironinstitute/NoRMCorre';
    S(i).DownloadUrl = 'https://github.com/flatironinstitute/NoRMCorre/archive/refs/heads/master.zip';
    S(i).HasSetupFile = false;
    S(i).SetupFileName = '';
    S(i).FunctionName = 'normcorre_batch';
    
    
end