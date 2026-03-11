# Verify SQL File

Validate a SQL file before application to prevent schema mismatches and data corruption.

## Steps
1. Read the target SQL file
2. For each INSERT statement:
   - Run `DESCRIBE <table>` via mysql MCP
   - Count columns in the VALUES clause
   - Verify column count matches table schema
   - Check column names if specified
3. For each UPDATE statement:
   - Verify SET columns exist in the table
   - Verify WHERE clause is not empty (no blanket updates)
4. For each DELETE statement:
   - Verify WHERE clause exists
   - Estimate affected rows with SELECT COUNT first
5. For SmartAI entries:
   - Validate event_type, action_type, target_type against known enums
   - Check for deprecated types
6. Report results with specific line numbers for any issues

## Output
Pass/fail with line-by-line validation results. Quote actual DESCRIBE output as evidence.
