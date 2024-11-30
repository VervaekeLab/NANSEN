function testImageStackLastModified()

    fileName = [tempname(), '_test_stack.bin'];

    virtualData = nansen.stack.virtual.Binary(fileName, [20,20,5], 'uint16');
    delete(virtualData)

    virtualData = nansen.stack.virtual.Binary(fileName);
    virtualData(1,1,1) = 15000;
    delete(virtualData)

    virtualData = nansen.stack.virtual.Binary(fileName);
    assert( virtualData(1,1,1) == 15000, ...
        'First array value is not the expected value')

    delete(virtualData)
    delete(fileName)
end