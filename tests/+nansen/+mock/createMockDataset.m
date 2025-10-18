function createMockDataset(datasetDirectory)
% CREATEMOCKDATASET Create a mock dataset for testing NANSEN
%
%   CREATEMOCKDATASET(datasetDirectory) creates a mock dataset in the
%   specified directory following BIDS organization with 3 subjects and
%   2 sessions per subject. Each session contains simulated neural signals
%   and metadata.
%
%   The dataset includes:
%   - 3 subjects (sub-01, sub-02, sub-03)
%   - 2 sessions per subject (ses-01, ses-02)
%   - Subject metadata (JSON format)
%   - Session metadata (JSON format) including imaging depth and brain region
%   - Neural signal data (MAT format, time x neurons)
%
%   This function is used for testing the NANSEN toolbox.

    % Create the main dataset directory if it doesn't exist
    if ~exist(datasetDirectory, 'dir')
        mkdir(datasetDirectory);
    end
    
    % Create dataset description file
    createDatasetDescription(datasetDirectory);
    
    % Create subjects and sessions
    subjects = {'sub-01', 'sub-02', 'sub-03'};
    sessions = {'ses-01', 'ses-02'};
    
    % Brain regions to use for sessions
    brainRegions = {'visual cortex', 'hippocampus', 'prefrontal cortex', ...
                   'somatosensory cortex', 'motor cortex'};
    
    for i = 1:length(subjects)
        subjectDir = fullfile(datasetDirectory, subjects{i});
        createSubject(subjectDir, subjects{i});
        
        for j = 1:length(sessions)
            sessionDir = fullfile(subjectDir, [subjects{i}, '_', sessions{j}]);
            
            % Select a random brain region for this session
            brainRegion = brainRegions{randi(length(brainRegions))};
            
            % Generate a random imaging depth between 150-350 micrometers
            imagingDepth = randi([150, 350]);
            
            createSession(sessionDir, subjects{i}, sessions{j}, brainRegion, imagingDepth);
        end
    end
    
    fprintf('Mock dataset created successfully in %s\n', datasetDirectory);
end

function createDatasetDescription(datasetDirectory)
% Create a dataset description file in JSON format
    
    description = struct();
    description.Name = 'NANSEN Mock Dataset';
    description.BIDSVersion = '1.6.0';
    description.Description = 'Mock dataset for testing NANSEN toolbox';
    description.Authors = {'NANSEN Test Suite'};
    description.DatasetType = 'raw';
    
    % Save as JSON
    descriptionFile = fullfile(datasetDirectory, 'dataset_description.json');
    saveJSON(descriptionFile, description);
    
    fprintf('Created dataset description file\n');
end

function createSubject(subjectDir, subjectId)
% Create a subject directory with metadata
    
    if ~exist(subjectDir, 'dir')
        mkdir(subjectDir);
    end
    
    % Create subject metadata
    metadata = struct();
    metadata.subject_id = subjectId;
    metadata.species = 'mus musculus';
    metadata.strain = 'C57BL/6J';
    
    % Randomize some metadata
    ages = [8, 10, 12, 14, 16];
    sexes = {'M', 'F'};
    weights = [20, 22, 24, 26, 28, 30];
    
    metadata.age_weeks = ages(randi(length(ages)));
    metadata.sex = sexes{randi(length(sexes))};
    metadata.weight_g = weights(randi(length(weights)));
    
    % Save metadata as JSON
    metadataFile = fullfile(subjectDir, [subjectId, '_metadata.json']);
    saveJSON(metadataFile, metadata);
    
    fprintf('Created subject directory: %s\n', subjectId);
end

function createSession(sessionDir, subjectId, sessionId, brainRegion, imagingDepth)
% Create a session directory with metadata and neural data
    
    if ~exist(sessionDir, 'dir')
        mkdir(sessionDir);
    end
    
    % Create session metadata
    metadata = struct();
    metadata.session_id = sessionId;
    metadata.subject_id = subjectId;
    
    % Generate a random date within the last year
    currentDate = datetime('now');
    daysBack = randi([1, 365]);
    sessionDate = currentDate - days(daysBack);
    
    metadata.date = datestr(sessionDate, 'yyyy-mm-dd');
    metadata.time = datestr(sessionDate, 'HH:MM:SS');
    metadata.experiment_type = 'two-photon calcium imaging';
    metadata.brain_region = brainRegion;
    metadata.imaging_depth = imagingDepth;  % in micrometers
    
    % Add imaging parameters
    metadata.imaging_parameters = struct();
    metadata.imaging_parameters.frame_rate = 30;  % Hz
    metadata.imaging_parameters.resolution = [512, 512];  % pixels
    metadata.imaging_parameters.zoom = 2.0 + rand(1) * 1.0;  % Random zoom between 2.0 and 3.0
    metadata.imaging_parameters.laser_power = 20 + randi([0, 10]);  % mW, random between 20-30
    
    % Save metadata as JSON
    metadataFile = fullfile(sessionDir, [sessionId, '_metadata.json']);
    saveJSON(metadataFile, metadata);
    
    % Generate and save neural data
    neuralData = generateNeuralData(1000, 50);  % 1000 time points, 50 neurons
    neuralDataFile = fullfile(sessionDir, [sessionId, '_neural_data.mat']);
    save(neuralDataFile, 'neuralData');
    
    fprintf('Created session directory: %s/%s\n', subjectId, sessionId);
end

function data = generateNeuralData(numTimePoints, numNeurons)
% Generate simulated neural signals (calcium imaging data)
    
    % Initialize data matrix
    data = zeros(numTimePoints, numNeurons);
    
    % Parameters for calcium transients
    tau_rise = 2;    % frames
    tau_decay = 10;  % frames
    
    % Generate calcium transients for each neuron
    for n = 1:numNeurons
        % Random firing rate between 0.01 and 0.1 events per frame
        firingRate = 0.01 + 0.09 * rand();
        
        % Generate spike times
        spikeProb = rand(numTimePoints, 1);
        spikeTimes = find(spikeProb < firingRate);
        
        % Generate calcium transient kernel
        t = transpose(0:numTimePoints-1);
        kernel = exp(-t/tau_decay) - exp(-t/tau_rise);
        kernel = kernel / max(kernel);
        
        % Convolve spikes with kernel to get calcium signal
        signal = zeros(numTimePoints, 1);
        signal(spikeTimes) = 1;
        
        % Convolve with kernel
        calcium = conv(signal, kernel);
        calcium = calcium(1:numTimePoints);
        
        % Add noise
        noise = 0.1 * randn(numTimePoints, 1);
        
        % Final signal
        data(:, n) = calcium + noise;
    end
    
    % Ensure non-negative values
    data = max(data, 0);
end

function saveJSON(filename, data)
% Save data structure as JSON file
    
    % Convert to JSON string
    jsonStr = jsonencode(data, 'PrettyPrint', true);
    
    % Write to file
    fid = fopen(filename, 'w');
    if fid == -1
        error('Failed to open file for writing: %s', filename);
    end
    
    fprintf(fid, '%s', jsonStr);
    fclose(fid);
end
