function S = getNormCorreDefaultSettings()

S = struct();

S.Patches = struct();
S.Patches.numRows_ = struct('type', 'slider', 'args', {{'Min', 1, 'Max', 64, 'nTicks', 63}});
S.Patches.numRows           = 4;
S.Patches.numCols_ = struct('type', 'slider', 'args', {{'Min', 1, 'Max', 64, 'nTicks', 63}});
S.Patches.numCols           = 4;
S.Patches.patchOverlap      = [32,32,16];
S.Patches.maximumDeviation  = [15,15,1];
S.Patches.maximumShift      = [40,40,5];
S.Patches.shiftsMethod_     = {'FFT','cubic','linear'};
S.Patches.shiftsMethod      = 'FFT';

S.Template = struct();
S.Template.updateTemplate = true;
S.Template.initialBatchSize = 100;
S.Template.binWidth = 50;
S.Template.boundary = 'copy';
S.Template.boundary_ = {'NaN','copy','zero','template'};

S.Preview = struct();
S.Preview.firstFrame = 1;
S.Preview.numFrames = 500;
S.Preview.openResultInNewWindow = true;
S.Preview.run_ = struct('type', 'button', 'args', {{'String', 'Run Test Aligning'}});
S.Preview.run = false;



S.Export = struct();
S.Export.saveParemetersToFile_ = 'uiputfile';
S.Export.saveParemetersToFile = '';
S.Export.PreviewSaveFolder_ = 'uigetdir';
S.Export.PreviewSaveFolder = '';
S.Export.OutputFormat = 'Binary';
S.Export.OutputFormat_ = {'Binary', 'Tiff'};


S.Presets.Name = 'custom';
S.Presets.Name_ = {'default', 'fft', '4x1', '8x1', 'custom'};

return

end

% % % 
% % % sCell = struct2cell(S);
% % % names = fieldnames(S);
% % % 
% % % clib.structEditor(sCell, 'NoRMCorre Settings', 'Name', names)
% % % 
% % % 
% % %     % patches
% % %     'grid_size          ' % size of non-overlapping regions (default: [d1,d2,d3])
% % %     'overlap_pre        ' % size of overlapping region (default: [32,32,16])
% % %     'min_patch_size     ' % minimum size of patch (default: [32,32,16])    
% % %     'min_diff           ' % minimum difference between patches (default: [16,16,5])
% % %     'us_fac             ' % upsampling factor for subpixel registration (default: 20)
% % %     'mot_uf             ' % degree of patches upsampling (default: [4,4,1])
% % %     'max_dev            ' % maximum deviation of patch shift from rigid shift (default: [3,3,1])
% % %     'overlap_post       ' % size of overlapping region after upsampling (default: [32,32,16])
% % %     'max_shift          ' % maximum rigid shift in each direction (default: [15,15,5])
% % %     'phase_flag         ' % flag for using phase correlation (default: false)
% % %     'shifts_method      ' % method to apply shifts ('FFT','cubic','linear')
% % %     % template updating
% % %     'upd_template       ' % flag for online template updating (default: true)
% % %     'init_batch         ' % length of initial batch (default: 100)
% % %     'bin_width          ' % width of each bin (default: 10)
% % %     'buffer_width       ' % number of local means to keep in memory (default: 50)
% % %     'method             ' % method for averaging the template (default: {'median';'mean})
% % %     'iter               ' % number of data passes (default: 1)
% % %     'boundary           ' % method of boundary treatment 'NaN','copy','zero','template' (default: 'copy')
% % %     % misc
% % %     'add_value          ' % add dc value to data (default: 0)
% % %     'use_parallel       ' % for each frame, update patches in parallel (default: false)
% % %     'memmap             ' % flag for saving memory mapped motion corrected file (default: false)
% % %     'mem_filename       ' % name for memory mapped file (default: 'motion_corrected.mat')
% % %     'mem_batch_size     ' % batch size during memory mapping for speed (default: 5000)
% % %     'print_msg          ' % flag for printing progress to command line (default: true)
% % %     % plotting
% % %     'plot_flag          ' % flag for plotting results in real time (default: false)
% % %     'make_avi           ' % flag for making movie (default: false)
% % %     'name               ' % name for movie (default: 'motion_corrected.avi')
% % %     'fr                 ' % frame rate for movie (default: 30)
% % %     % output type
% % %     'output_type        ' % 'mat' (load in memory), 'memmap', 'tiff', 'hdf5', 'bin' (default:mat)
% % %     'h5_groupname       ' % name for hdf5 dataset (default: 'mov')
% % %     'h5_filename        ' % name for hdf5 saved file (default: 'motion_corrected.h5')
% % %     'tiff_filename      ' % name for saved tiff stack (default: 'motion_corrected.tif')
% % %     'output_filename    ' % name for saved file will be used if `h5_,tiff_filename` are not specified
% % %     % use windowing
% % %     'use_windowing      ' % flag for windowing data before fft (default: false)
% % %     'window_length      ' % length of window on each side of the signal as a fraction of signal length
% % %                            %    total length = length(signal)(1 + 2*window_length). (default: 0.5)
% % %     % bitsize for reading .raw files
% % %     'bitsize            ' % (default: 2 (uint16). other choices 1 (uint8), 4 (single), 8 (double))
% % %     % offset from bidirectional sampling
% % %     'correct_bidir      ' % check for offset due to bidirectional scanning (default: true)
% % %     'nFrames            ' % number of frames to average (default: 50)
% % %     'bidir_us           ' % upsampling factor for bidirectional sampling (default: 10)
% % %     'col_shift          ' % known bi-directional offset provided by the user (default: [])
% % % 
% % % 
% % % 
% % % end