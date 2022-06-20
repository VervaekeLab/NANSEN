function divergence = get_mean_divergence(w)

    divergence = zeros(1, size(w, 4));

    u = w(:, :, 1, :);
    v = w(:, :, 2, :);

    parfor i = 1:size(w, 4)
        [w_x, ~] = imgradientxy(u(:, :, 1, i));
        [~, w_y] = imgradientxy(v(:, :, 1, i));

        divergence(i) = mean(mean(w_x + w_y, 1), 2);
    end
end
