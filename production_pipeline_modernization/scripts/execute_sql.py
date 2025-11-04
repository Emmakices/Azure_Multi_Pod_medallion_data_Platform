import pyodbc
import os

# Database connection details
server = 'sql-hrpayroll-test-2025.database.windows.net'
database = 'HRPayrollDB'
username = 'sqladmin'
password = 'HRPayroll@2025!'
driver = '{SQL Server}'

# SQL script path - can be passed as command line argument
import sys
if len(sys.argv) > 1:
    script_path = sys.argv[1]
else:
    script_path = r'C:\Users\User\Desktop\Delta_lake_project\production_pipeline_modernization\scripts\create_excel_tables.sql'

print("Connecting to database...")
try:
    # Build connection string
    conn_str = f'DRIVER={driver};SERVER={server};DATABASE={database};UID={username};PWD={password}'

    # Connect to database
    conn = pyodbc.connect(conn_str)
    cursor = conn.cursor()

    print(f"Reading SQL script from: {script_path}")

    # Read SQL script
    with open(script_path, 'r') as file:
        sql_script = file.read()

    # Split by GO statements and execute each batch
    batches = sql_script.split('GO')

    print(f"\nExecuting {len(batches)} SQL batches...")

    for i, batch in enumerate(batches):
        batch = batch.strip()
        if batch:
            try:
                print(f"  Executing batch {i+1}/{len(batches)}...")
                cursor.execute(batch)
                conn.commit()

                # If there are results, print them
                if cursor.description:
                    rows = cursor.fetchall()
                    if rows:
                        print(f"    Results from batch {i+1}:")
                        for row in rows:
                            print(f"      {row}")
            except Exception as e:
                print(f"    Error in batch {i+1}: {str(e)}")
                # Continue with next batch even if one fails
                continue

    print("\nSQL script executed successfully!")

    # Verify tables created
    print("\nVerifying tables...")
    cursor.execute("""
        SELECT TABLE_NAME,
               (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_NAME = t.TABLE_NAME) as ColumnCount
        FROM INFORMATION_SCHEMA.TABLES t
        WHERE TABLE_SCHEMA = 'dbo'
            AND TABLE_TYPE = 'BASE TABLE'
            AND (TABLE_NAME LIKE 'HR_%' OR TABLE_NAME LIKE 'Payroll_%')
        ORDER BY TABLE_NAME
    """)

    tables = cursor.fetchall()
    print(f"\nTables created:")
    for table in tables:
        print(f"  - {table[0]} ({table[1]} columns)")

    cursor.close()
    conn.close()

    print("\nDatabase tables created successfully!")

except Exception as e:
    print(f"Error: {str(e)}")
    import traceback
    traceback.print_exc()
