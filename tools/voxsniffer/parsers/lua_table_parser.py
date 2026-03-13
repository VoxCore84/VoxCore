"""Parse WoW SavedVariables Lua table format into Python dicts.

WoW SavedVariables are Lua table literals:
    VoxSnifferDB = {
        ["schema_version"] = 1,
        ["sessions"] = {
            [1] = {
                ["session_id"] = 1,
                ...
            },
        },
    }

This parser handles:
- String keys: ["key"] = value
- Numeric keys: [1] = value
- Nested tables: { ... }
- String values: "text" (with escape handling)
- Number values: 123, 1.5, -42
- Boolean values: true, false
- nil values (skipped)
"""

import re
from typing import Any


class LuaParseError(Exception):
    """Raised when Lua table parsing fails."""
    pass


class LuaTableParser:
    """Parse Lua table literals from SavedVariables files."""

    def __init__(self, text: str):
        self.text = text
        self.pos = 0
        self.length = len(text)

    def _skip_whitespace(self):
        while self.pos < self.length and self.text[self.pos] in ' \t\r\n':
            self.pos += 1
        # Skip comments
        if self.pos < self.length - 1 and self.text[self.pos:self.pos+2] == '--':
            # Single line comment
            while self.pos < self.length and self.text[self.pos] != '\n':
                self.pos += 1
            self._skip_whitespace()

    def _peek(self) -> str:
        self._skip_whitespace()
        if self.pos >= self.length:
            return ''
        return self.text[self.pos]

    def _expect(self, ch: str):
        self._skip_whitespace()
        if self.pos >= self.length or self.text[self.pos] != ch:
            context = self.text[max(0, self.pos-20):self.pos+20]
            raise LuaParseError(f"Expected '{ch}' at pos {self.pos}, got '{self.text[self.pos] if self.pos < self.length else 'EOF'}'. Context: ...{context}...")
        self.pos += 1

    def parse_value(self) -> Any:
        self._skip_whitespace()
        if self.pos >= self.length:
            raise LuaParseError("Unexpected end of input")

        ch = self.text[self.pos]

        if ch == '{':
            return self.parse_table()
        elif ch == '"':
            return self.parse_string()
        elif ch == '-' or ch.isdigit():
            return self.parse_number()
        elif self.text[self.pos:self.pos+4] == 'true':
            self.pos += 4
            return True
        elif self.text[self.pos:self.pos+5] == 'false':
            self.pos += 5
            return False
        elif self.text[self.pos:self.pos+3] == 'nil':
            self.pos += 3
            return None
        else:
            context = self.text[max(0, self.pos-10):self.pos+20]
            raise LuaParseError(f"Unexpected character '{ch}' at pos {self.pos}. Context: ...{context}...")

    def parse_string(self) -> str:
        self._expect('"')
        parts = []
        while self.pos < self.length:
            ch = self.text[self.pos]
            if ch == '\\':
                self.pos += 1
                if self.pos >= self.length:
                    break
                esc = self.text[self.pos]
                if esc == 'n':
                    parts.append('\n')
                elif esc == 't':
                    parts.append('\t')
                elif esc == '\\':
                    parts.append('\\')
                elif esc == '"':
                    parts.append('"')
                elif esc == '\n':
                    parts.append('\n')
                else:
                    parts.append(esc)
                self.pos += 1
            elif ch == '"':
                self.pos += 1
                return ''.join(parts)
            else:
                parts.append(ch)
                self.pos += 1
        raise LuaParseError("Unterminated string")

    def parse_number(self) -> float | int:
        start = self.pos
        if self.text[self.pos] == '-':
            self.pos += 1
        while self.pos < self.length and (self.text[self.pos].isdigit() or self.text[self.pos] == '.'):
            self.pos += 1
        # Handle scientific notation
        if self.pos < self.length and self.text[self.pos] in 'eE':
            self.pos += 1
            if self.pos < self.length and self.text[self.pos] in '+-':
                self.pos += 1
            while self.pos < self.length and self.text[self.pos].isdigit():
                self.pos += 1

        num_str = self.text[start:self.pos]
        if '.' in num_str or 'e' in num_str or 'E' in num_str:
            return float(num_str)
        return int(num_str)

    def parse_table(self) -> dict | list:
        self._expect('{')

        # Detect if this is an array-like table (sequential numeric keys starting at 1)
        # or a dict-like table (string keys or non-sequential)
        result = {}
        max_int_key = 0
        has_string_keys = False

        while True:
            self._skip_whitespace()
            if self.pos >= self.length:
                raise LuaParseError("Unterminated table")
            if self.text[self.pos] == '}':
                self.pos += 1
                break

            # Parse key
            if self.text[self.pos] == '[':
                self.pos += 1
                self._skip_whitespace()
                if self.text[self.pos] == '"':
                    key = self.parse_string()
                    has_string_keys = True
                else:
                    key = self.parse_number()
                    if isinstance(key, int) and key > max_int_key:
                        max_int_key = key
                self._expect(']')
                self._skip_whitespace()
                self._expect('=')
                value = self.parse_value()
                result[key] = value
            else:
                # Bare identifier key: key = value
                start = self.pos
                while self.pos < self.length and (self.text[self.pos].isalnum() or self.text[self.pos] == '_'):
                    self.pos += 1
                key = self.text[start:self.pos]
                has_string_keys = True
                self._skip_whitespace()
                self._expect('=')
                value = self.parse_value()
                result[key] = value

            # Optional comma
            self._skip_whitespace()
            if self.pos < self.length and self.text[self.pos] == ',':
                self.pos += 1

        # Convert to list if all keys are sequential integers 1..N
        if not has_string_keys and max_int_key > 0 and max_int_key == len(result):
            all_sequential = all(isinstance(k, int) and 1 <= k <= max_int_key for k in result.keys())
            if all_sequential:
                return [result[i] for i in range(1, max_int_key + 1)]

        return result


def parse_lua_table(text: str) -> Any:
    """Parse a Lua table literal string into a Python object."""
    parser = LuaTableParser(text)
    return parser.parse_value()


def load_savedvariables(filepath: str) -> dict[str, Any]:
    """Load a WoW SavedVariables .lua file and return all top-level assignments.

    Returns a dict mapping variable names to their parsed values.
    Example: {"VoxSnifferDB": {...}}
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all top-level assignments: VarName = { ... }
    results = {}
    pattern = re.compile(r'^(\w+)\s*=\s*', re.MULTILINE)

    for match in pattern.finditer(content):
        var_name = match.group(1)
        start = match.end()

        # Parse the value starting from the assignment
        try:
            parser = LuaTableParser(content[start:])
            value = parser.parse_value()
            results[var_name] = value
        except LuaParseError:
            # Skip unparseable assignments
            continue

    return results
