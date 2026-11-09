function applyMigrationSteps(storedVersion, steps, recordVersion)
%applyMigrationSteps Run the numbered migration steps that stored data has not had
%
%   applyMigrationSteps(storedVersion, steps, recordVersion) runs, in
%   order, every step with a Version above storedVersion, and calls
%   recordVersion(step.Version) as soon as a step has finished. Data that
%   is several versions behind therefore passes through every step
%   between, and a chain that stops partway resumes after the last step
%   that finished.
%
%   steps is a struct array with the fields
%       Version     - version of the data after this step. Versions must
%                     increase by one from each step to the next.
%       Description - what the step changes, used in the error message
%       Apply       - handle to a function without inputs that does the work
%
%   A step must leave the data as it found it when it fails, and it must
%   tolerate a folder or file that it would change being absent.
%
%   Throws:
%       NANSEN:Migration:InvalidSteps - the versions of steps are not
%           consecutive. Nothing was run.
%       NANSEN:Migration:StepFailed - a step threw an error, which is
%           attached as the cause. No later step was run.

    arguments
        storedVersion (1,1) double
        steps struct
        recordVersion (1,1) function_handle
    end

    versions = [steps.Version];

    if any(diff(versions) ~= 1)
        error('NANSEN:Migration:InvalidSteps', ...
            ['Migration steps must be numbered one apart and in order, ' ...
             'but their versions are %s.'], mat2str(versions))
    end

    for step = reshape(steps(versions > storedVersion), 1, [])
        try
            step.Apply()
        catch cause
            ME = MException('NANSEN:Migration:StepFailed', ...
                'Migration to version %d failed (%s), so the data stays at version %d.', ...
                step.Version, step.Description, step.Version - 1);
            ME = ME.addCause(cause);
            throw(ME)
        end

        recordVersion(step.Version)
    end
end
