path = r'README.md'
with open(path, 'r', encoding='utf-8') as f:
    c = f.read()
c = c.replace('\u2019', "'")
with open(path, 'w', encoding='utf-8') as f:
    f.write(c)
print('Done')
