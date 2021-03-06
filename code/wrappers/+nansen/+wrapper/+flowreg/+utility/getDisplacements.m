function shifts = getDisplacements(C, CRef, options, varargin)
%getDisplacements Wrapper for get_displacements

        shifts = get_displacements( ...
            C, CRef, ...
            'sigma', 0.001, ...
            'alpha', options.alpha, ...
            'levels', options.levels, ...
            'min_level', options.min_level, ...
            'eta', options.eta, ...
            'update_lag', options.update_lag, ...
            'iterations', options.iterations, ...
            'a_smooth', options.a_smooth, ...
            'a_data', options.a_data, ...
            varargin{:});
end
