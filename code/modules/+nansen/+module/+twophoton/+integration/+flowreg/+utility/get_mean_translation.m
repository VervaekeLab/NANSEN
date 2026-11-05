function mean_translation = get_mean_translation(w)

    u = mean(mean(w(:, :, 1, :), 1), 2);
    v = mean(mean(w(:, :, 2, :), 1), 2);

    mean_translation = squeeze(sqrt(u.^2 + v.^2));
end
