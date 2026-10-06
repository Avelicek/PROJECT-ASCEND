"""Conservative lexical delimiter check; not a Swift parser or compiler."""
from pathlib import Path

def check_source(source):
    cursor = 0
    pairs = {'(': ')', '[': ']', '{': '}'}
    def string():
        nonlocal cursor
        terminator = '"""' if source.startswith('"""', cursor) else '"'
        cursor += len(terminator)
        while cursor < len(source):
            if source.startswith(terminator, cursor):
                cursor += len(terminator)
                return
            if source.startswith('\\(', cursor):
                cursor += 2
                code(')')
            elif source[cursor] == '\\':
                cursor += 2
            else:
                cursor += 1
        raise AssertionError('Unterminated string')
    def code(stop=None):
        nonlocal cursor
        stack = []
        while cursor < len(source):
            if source.startswith('//', cursor):
                cursor = source.find('\n', cursor)
                if cursor == -1: cursor = len(source)
                continue
            if source.startswith('/*', cursor):
                depth = 1; cursor += 2
                while depth and cursor < len(source):
                    if source.startswith('/*', cursor): depth += 1; cursor += 2
                    elif source.startswith('*/', cursor): depth -= 1; cursor += 2
                    else: cursor += 1
                if depth: raise AssertionError('Unterminated block comment')
                continue
            char = source[cursor]
            if char == '"': string(); continue
            if char in pairs: stack.append(pairs[char]); cursor += 1; continue
            if char in ')]}':
                if not stack and char == stop: cursor += 1; return
                if not stack or stack.pop() != char:
                    line = source.count('\n', 0, cursor) + 1
                    raise AssertionError(f'Mismatched delimiter at line {line}')
            cursor += 1
        if stack or stop: raise AssertionError('Unclosed delimiter or interpolation')
    code()

if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    sources = list((root/'ASCEND').rglob('*.swift')) + list((root/'Tests').rglob('*.swift')) + [root/'Package.swift']
    for path in sources:
        try: check_source(path.read_text(encoding='utf8'))
        except AssertionError as error: raise AssertionError(f'{path.relative_to(root)}: {error}') from error
    print(f'Lexical delimiters balanced in {len(sources)} Swift files. Swift syntax/types/macros remain unverified.')
