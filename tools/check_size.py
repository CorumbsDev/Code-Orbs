import struct
files=['botao_1.png', 'botao_2.png', 'botao_3.png', 'botao_4.png']
for f in files:
    path = r'Inventory\Art\UI\butoes\\' + f
    try:
        with open(path, 'rb') as file:
            data = file.read(24)
            if data[:8] == b'\x89PNG\r\n\x1a\n':
                w, h = struct.unpack('>II', data[16:24])
                print(f'{f}: {w}x{h}')
    except Exception as e:
        print(f'Failed {f}: {e}')
