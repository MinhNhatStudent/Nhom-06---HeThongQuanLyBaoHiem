"""
Database connection and utility functions
"""
import mysql.connector
from mysql.connector import pooling
from ..config.settings import get_settings

# Get application settings
settings = get_settings()

# Create connection pool
connection_pool = pooling.MySQLConnectionPool(
    pool_name="insurance_pool",
    pool_size=5,
    host=settings.db.host,
    port=settings.db.port,
    user=settings.db.user,
    password=settings.db.password,
    database=settings.db.database
)

def get_connection():
    """Get a connection from the connection pool"""
    try:
        return connection_pool.get_connection()
    except mysql.connector.Error as err:
        print(f"Error connecting to MySQL: {err}")
        raise

def execute_procedure(procedure_name, params=None):
    """Execute a stored procedure and return results"""
    connection = None
    cursor = None
    try:
        connection = get_connection()
        cursor = connection.cursor(dictionary=True)
        
        if params:
            cursor.callproc(procedure_name, params)
        else:
            cursor.callproc(procedure_name)
        
        # Get all result sets
        results = []
        for result in cursor.stored_results():
            results.append(result.fetchall())
        
        # COMMIT THE TRANSACTION to save changes to the database
        connection.commit()
        
        # If there's only one result set, return it directly
        if len(results) == 1:
            return results[0]
        return results
        
    except mysql.connector.Error as err:
        print(f"Error executing stored procedure {procedure_name}: {err}")
        # Rollback in case of error
        if connection:
            connection.rollback()
        raise
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()
