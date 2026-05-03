function linkStr = createCommandWindowWebLink(url, title)

    arguments
        url (1,:) char
        title (1,:) char
    end

    linkStr = sprintf('<a href="matlab:web %s -browser" style="font-weight:bold">%s</a>', url, title);
end
