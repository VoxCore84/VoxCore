"""Tests for the Lua table parser."""

import pytest
from tools.voxsniffer.parsers.lua_table_parser import parse_lua_table, load_savedvariables, LuaParseError

# ── Basic value parsing ──

def test_parse_number_int():
    assert parse_lua_table("42") == 42

def test_parse_number_negative():
    assert parse_lua_table("-7") == -7

def test_parse_number_float():
    assert parse_lua_table("3.14") == 3.14

def test_parse_string():
    assert parse_lua_table('"hello world"') == "hello world"

def test_parse_string_escapes():
    assert parse_lua_table(r'"line1\nline2"') == "line1\nline2"

def test_parse_bool_true():
    assert parse_lua_table("true") is True

def test_parse_bool_false():
    assert parse_lua_table("false") is False

def test_parse_nil():
    assert parse_lua_table("nil") is None

# ── Table parsing ──

def test_parse_empty_table():
    assert parse_lua_table("{}") == {}

def test_parse_dict_table():
    result = parse_lua_table('{ ["name"] = "Test", ["level"] = 80 }')
    assert result == {"name": "Test", "level": 80}

def test_parse_array_table():
    result = parse_lua_table('{ [1] = "a", [2] = "b", [3] = "c" }')
    assert result == ["a", "b", "c"]

def test_parse_nested_table():
    lua = '{ ["outer"] = { ["inner"] = 42 } }'
    result = parse_lua_table(lua)
    assert result == {"outer": {"inner": 42}}

def test_parse_mixed_keys():
    lua = '{ ["name"] = "Test", [1] = "first" }'
    result = parse_lua_table(lua)
    assert result["name"] == "Test"
    assert result[1] == "first"

def test_parse_trailing_comma():
    result = parse_lua_table('{ ["a"] = 1, ["b"] = 2, }')
    assert result == {"a": 1, "b": 2}

def test_parse_bare_key():
    result = parse_lua_table('{ name = "Test", level = 80 }')
    assert result == {"name": "Test", "level": 80}

# ── Comment handling ──

def test_skip_line_comment():
    lua = '{ ["a"] = 1, -- this is a comment\n ["b"] = 2 }'
    result = parse_lua_table(lua)
    assert result == {"a": 1, "b": 2}

# ── Error handling ──

def test_unterminated_table():
    with pytest.raises(LuaParseError):
        parse_lua_table('{ ["a"] = 1')

def test_unterminated_string():
    with pytest.raises(LuaParseError):
        parse_lua_table('"hello')

# ── Realistic WoW SavedVariables ──

def test_parse_observation_envelope():
    lua = """{
        ["t"] = "unit_seen",
        ["ek"] = "C:12345",
        ["sid"] = 1,
        ["map"] = 84,
        ["zone"] = "Stormwind City",
        ["ts"] = 100.5,
        ["epoch"] = 1710288100,
        ["src"] = "UnitScanner",
        ["p"] = {
            ["name"] = "Stormwind Guard",
            ["level"] = 80,
        },
    }"""
    result = parse_lua_table(lua)
    assert result["t"] == "unit_seen"
    assert result["ek"] == "C:12345"
    assert result["p"]["name"] == "Stormwind Guard"
    assert result["p"]["level"] == 80
