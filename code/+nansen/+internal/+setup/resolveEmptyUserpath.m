function resolveEmptyUserpath()
    
    prompt = [ 'Please enter the path name of a directory which NANSEN ', ...
        'can use for saving userdata \nand dependencies like addons and ', ...
        'toolboxes. Note: MATLAB/Nansen will be appended to \nthe path ', ...
        'you enter.\nEnter path name: '];

    answer = input(prompt, 's');
    if isempty(answer)
        error('NANSEN:SetUserpathAborted', 'Please enter a directory for userdata')
    end

    enteredPath = answer;
    userPathDirectory = fullfile(enteredPath, 'MATLAB');
    directoryPath = fullfile(userPathDirectory, 'Nansen');

    if ~isfolder(directoryPath)
        % Ask user if they want to create the directory
        prompt = sprintf([ '\nThe directory "%s" does not exist.\n', ...
            'Do you want to create it?\n', ...
            'Enter "y" for yes or "n" for no: '], directoryPath);
        answer = input(prompt, 's');
        if isempty(answer)
            error('NANSEN:SetUserpathAborted', 'Please enter "y" or "n"')
        end
        if strcmpi(answer, 'y')
            mkdir(directoryPath)
        else
            error('NANSEN:SetUserpathAborted', 'A directory for userdata is required')
        end
    end

    % Add the directory to the userpath
    %userpath(userPathDirectory)
    fprintf('Updated MATLAB''s userpath to: "%s"\n', userPathDirectory)
    fprintf(newline)
end
