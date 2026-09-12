function weight = getFlowregChannelWeights(Y, options)

    n_channels = size(Y, 3);

    % setting the channel weight
    weight = [];
    for i = 1:n_channels
        weight(:, :, i) = options.get_weight_at(i, n_channels);
    end
end
