function S = getDefaultAddonList()
%getAddonList Return a list of addons that are needed

% Name          : Name of addon toolbox
% Source        : Where to download addon from (FileExchange or GitHub)
% WebUrl        : Web Url for addon download
% HasSetupFile  : Is there a setup file that should be run?
% SetupName     : Name of setup file if there are any
% FunctionName  : Name of function in repository (used to check if repository already exists on matlab's path)
    
% Todo: Add git commit id, and use it for checking if latest version is
% downloaded...
% Use git instead of downloading zipped versions of repositories...

    i = 1;
    S(i).Name = 'Widgets Toolbox';
    S(i).Description = 'Additional app building components';
    S(i).IsRequired = true;
    S(i).Type = 'General';
    S(i).Source = 'FileExchange';
    S(i).WebUrl = 'https://se.mathworks.com/matlabcentral/fileexchange/66235-widgets-toolbox-compatibility-support?s_tid=srchtitle';
    % Newest version is commented out because it has some bugs. Use a
    % previous version that works.
    %S(i).DownloadUrl = 'https://se.mathworks.com/matlabcentral/mlc-downloads/downloads/b0bebf59-856a-4068-9d9c-0ed8968ac9e6/a22b68d6-b5aa-48cb-87fa-1f4a763578e0/packages/zip';
    S(i).DownloadUrl = 'https://www.mathworks.com/matlabcentral/mlc-downloads/downloads/b0bebf59-856a-4068-9d9c-0ed8968ac9e6/099f0a4d-9837-4e5f-b3df-aa7d4ec9c9c9/packages/zip';
    %S(i).DownloadUrl = 'https://www.mathworks.com/matlabcentral/mlc-downloads/downloads/78895307-cc36-4970-8b66-0697da8f9352/4ae5c052-7f28-4fcf-9383-0d6ce4622d22/packages/mltbx'; % MATLAB TOOLBOX
    S(i).HasSetupFile = false;
    S(i).SetupFileName = 'nansen.config.path.addUiwidgetsJarToJavaClassPath';
    S(i).FunctionName = 'uiw.abstract.AppWindow';
    
% %     i = i + 1; % Comment out because its not used.
% %     S(i).Name = 'GUI Layout Toolbox';
% %     S(i).Description = 'Layout manager for MATLAB graphical user interfaces';
% %     S(i).IsRequired = true;
% %     S(i).Type = 'General';
% %     S(i).Source = 'FileExchange';
% %     S(i).WebUrl = 'https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox';
% %     S(i).DownloadUrl = 'https://se.mathworks.com/matlabcentral/mlc-downloads/downloads/e5af5a78-4a80-11e4-9553-005056977bd0/df368ddb-983a-439f-86cb-04e375916c75/packages/zip';
% %     %S(i).DownloadUrl = 'https://se.mathworks.com/matlabcentral/mlc-downloads/downloads/e5af5a78-4a80-11e4-9553-005056977bd0/2.3.5/packages/mltbx'; % MATLAB TOOLBOX
% %     S(i).HasSetupFile = false;
% %     S(i).SetupFileName = '';
% %     S(i).FunctionName = 'uix.BoxPanel';
    
    i = i + 1;
    S(i).Name = 'YAML-Matlab';
    S(i).Description = 'Reading in and writing out a yaml file.';
    S(i).IsRequired = true;
    S(i).Type = 'General';
    S(i).Source = 'Github';
    S(i).WebUrl = 'https://github.com/ewiger/yamlmatlab';
    S(i).DownloadUrl = 'https://github.com/ehennestad/yamlmatlab/archive/refs/heads/master.zip'; % Fixed some bugs with original
    S(i).HasSetupFile = false;
    S(i).SetupFileName = 'nansen.config.path.addYamlJarToJavaClassPath';
    S(i).FunctionName = 'yaml.WriteYaml';
    
    i = i + 1;
    S(i).Name = 'TIFFStack';
    S(i).Description = 'Package for creating virtual tiff stack (Used for ScanImage tiff files).';
    S(i).IsRequired = false;
    S(i).Type = 'General';
    S(i).Source = 'Github';
    S(i).WebUrl = 'https://github.com/DylanMuir/TIFFStack';
    S(i).DownloadUrl = 'https://github.com/DylanMuir/TIFFStack/archive/refs/heads/master.zip';
    S(i).HasSetupFile = false;
    S(i).SetupFileName = '';
    S(i).FunctionName = 'TIFFStack';
        
    i = i + 1;
    S(i).Name = 'CaImAn-Matlab';
    S(i).Description = 'A Computational toolbox for large scale Calcium Imaging data Analysis';
    S(i).IsRequired = false;
    S(i).Type = 'Neuroscience';
    S(i).Source = 'Github';
    S(i).WebUrl = 'https://github.com/flatironinstitute/CaImAn-MATLAB';
    S(i).DownloadUrl = 'https://github.com/flatironinstitute/CaImAn-MATLAB/archive/refs/heads/master.zip';
    S(i).HasSetupFile = false;
    S(i).SetupFileName = '';
    S(i).FunctionName = 'CNMFSetParms';
    i = i + 1;

    S(i).Name = 'suite2P-Matlab';
    S(i).Description = 'Fast, accurate and complete two-photon pipeline';
    S(i).IsRequired = false;
    S(i).Type = 'Neuroscience';
    S(i).Source = 'Github';
    S(i).WebUrl = 'https://github.com/cortex-lab/Suite2P';
    S(i).DownloadUrl = 'https://github.com/cortex-lab/Suite2P/archive/refs/heads/master.zip';
    S(i).HasSetupFile = false;
    S(i).SetupFileName = '';
    S(i).FunctionName = 'build_ops3';
    
    i = i + 1;
    S(i).Name = 'EXTRACT';
    S(i).Description = 'Tractable and Robust Automated Cell extraction Tool for calcium imaging';
    S(i).IsRequired = false;
    S(i).Type = 'Neuroscience';
    S(i).Source = 'Github';
    S(i).WebUrl = 'https://github.com/schnitzer-lab/EXTRACT-public';
    S(i).DownloadUrl = 'https://github.com/schnitzer-lab/EXTRACT-public/archive/refs/heads/master.zip';
    S(i).HasSetupFile = false;
    S(i).SetupFileName = '';
    S(i).FunctionName = 'run_extract';
    S(i).RequiredToolboxes = { ...
        'Bioinformatics Toolbox', ...
        'Econometrics Toolbox', ...
        'Image Processing Toolbox', ...
        'Parallel Computing Toolbox', ...
        'Signal Processing Toolbox', ...
        'Statistics and Machine Learning Toolbox', ...
        'Wavelet Toolbox' };
    
    i = i + 1;
    S(i).Name = 'NoRMCorre';
    S(i).Description = ' Non-Rigid Motion Correction for calcium imaging data';
    S(i).IsRequired = false;
    S(i).Type = 'Neuroscience';
    S(i).Source = 'Github';
    S(i).WebUrl = 'https://github.com/flatironinstitute/NoRMCorre';
    %S(i).DownloadUrl = 'https://github.com/flatironinstitute/NoRMCorre/archive/refs/heads/master.zip';
    S(i).DownloadUrl = 'https://github.com/ehennestad/NoRMCorre/archive/refs/heads/master.zip';
    S(i).HasSetupFile = false;
    S(i).SetupFileName = '';
    S(i).FunctionName = 'normcorre_batch';
    
    i = i + 1;
    S(i).Name = 'Flow Registration';
    S(i).Description = ' Optical Flow based correction for calcium imaging data';
    S(i).IsRequired = false;
    S(i).Type = 'Neuroscience';
    S(i).Source = 'Github';
    S(i).WebUrl = 'https://github.com/phflot/flow_registration';
    S(i).DownloadUrl = 'https://github.com/phflot/flow_registration/archive/refs/heads/master.zip';
    S(i).HasSetupFile = true;
    S(i).SetupFileName = 'nansen.wrapper.flowreg.install'; %'set_path';
    S(i).FunctionName = 'OF_Options';
    
    i = i + 1;
    S(i).Name = 'SEUDO';
    S(i).Description = 'Calcium signal decontamination';
    S(i).IsRequired = false;
    S(i).Type = 'Neuroscience';
    S(i).Source = 'Github';
    S(i).WebUrl = 'https://github.com/adamshch/SEUDO';
    S(i).DownloadUrl = 'https://github.com/adamshch/SEUDO/archive/refs/heads/master.zip';
    S(i).HasSetupFile = false;
    S(i).SetupFileName = '';
    S(i).FunctionName = 'globalSEUDOWrapper.m';
    
    i = i + 1;
    S(i).Name = 'Neurodata Without Borders';
    S(i).Description = 'A Matlab interface for reading and writing NWB files';
    S(i).IsRequired = false;
    S(i).Type = 'Neuroscience';
    S(i).Source = 'Github';
    S(i).WebUrl = 'https://github.com/NeurodataWithoutBorders/matnwb';
    %S(i).DownloadUrl = 'https://github.com/NeurodataWithoutBorders/matnwb/archive/refs/heads/master.zip';
    S(i).DownloadUrl = 'https://github.com/ehennestad/matnwb/archive/refs/heads/master.zip';
    S(i).HasSetupFile = true;
    S(i).SetupFileName = 'generateCore';
    S(i).FunctionName = 'nwbRead.m';

    i = i + 1;
    S(i).Name = 'Brain Observatory Toolbox';
    S(i).Description = 'A MATLAB toolbox for interacting with the Allen Brain Observatory';
    S(i).IsRequired = false;
    S(i).Type = 'Neuroscience';
    S(i).Source = 'Github';
    S(i).WebUrl = 'https://github.com/emeyers/Brain-Observatory-Toolbox';
    S(i).DownloadUrl = 'https://github.com/emeyers/Brain-Observatory-Toolbox/archive/refs/heads/main.zip';
    S(i).HasSetupFile = false;
    S(i).SetupFileName = '';
    S(i).FunctionName = 'EphysQuickstart.mlx';

% %     i = i + 1 % Not implemented yet
% %     S(i).Name = 'PatchWarp';
% %     S(i).Description = 'Image processing pipeline to correct motion artifacts and complex image distortions in neuronal calcium imaging data.';
% %     S(i).IsRequired = false;
% %     S(i).Type = 'Neuroscience';
% %     S(i).Source = 'Github';
% %     S(i).WebUrl = 'https://github.com/ryhattori/PatchWarp';
% %     S(i).DownloadUrl = 'https://github.com/ryhattori/PatchWarp/archive/refs/heads/main.zip';
% %     S(i).HasSetupFile = false;
% %     S(i).SetupFileName = '';
% %     S(i).FunctionName = 'patchwarp.m';

end

% %     i = i + 1 % Not implemented yet
% %     S(i).Name = 'DABEST';
% %     S(i).Description = '';
% %     S(i).IsRequired = false;
% %     S(i).Type = 'Statistics';
% %     S(i).Source = 'Github';
% %     S(i).WebUrl = 'https://github.com/ACCLAB/DABEST-Matlab';
% %     S(i).DownloadUrl = 'https://github.com/ACCLAB/DABEST-Matlab/archive/refs/heads/master.zip';
% %     S(i).HasSetupFile = false;
% %     S(i).SetupFileName = '';
% %     S(i).FunctionName = 'dabest.m';
