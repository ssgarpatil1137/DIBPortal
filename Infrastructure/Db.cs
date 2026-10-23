using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;

namespace DFM.Web.Infrastructure
{
    public static class Db
    {
        public static SqlConnection Open()
        {
            var connection = new SqlConnection(ConfigurationManager.ConnectionStrings["DFM"].ConnectionString);
            connection.Open();
            using (var command = new SqlCommand("SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;", connection))
                command.ExecuteNonQuery();
            return connection;
        }

        public static object Value(object value) { return value ?? DBNull.Value; }

        public static List<Dictionary<string, object>> Query(string sql, params SqlParameter[] parameters)
        {
            var rows = new List<Dictionary<string, object>>();
            using (var connection = Open())
            using (var command = new SqlCommand(sql, connection))
            {
                command.Parameters.AddRange(parameters);
                using (var reader = command.ExecuteReader())
                    while (reader.Read())
                    {
                        var row = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
                        for (var index = 0; index < reader.FieldCount; index++)
                            row[reader.GetName(index)] = reader.IsDBNull(index) ? null : reader.GetValue(index);
                        rows.Add(row);
                    }
            }
            return rows;
        }

        // Reads every result set returned by a stored procedure (e.g. sp_GetProjectDetail's project/pets/spendItems/... sets).
        public static List<List<Dictionary<string, object>>> QueryMultiple(string sql, params SqlParameter[] parameters)
        {
            var results = new List<List<Dictionary<string, object>>>();
            using (var connection = Open())
            using (var command = new SqlCommand(sql, connection))
            {
                command.Parameters.AddRange(parameters);
                using (var reader = command.ExecuteReader())
                {
                    do
                    {
                        var rows = new List<Dictionary<string, object>>();
                        while (reader.Read())
                        {
                            var row = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
                            for (var index = 0; index < reader.FieldCount; index++)
                                row[reader.GetName(index)] = reader.IsDBNull(index) ? null : reader.GetValue(index);
                            rows.Add(row);
                        }
                        results.Add(rows);
                    } while (reader.NextResult());
                }
            }
            return results;
        }

        public static int Execute(string sql, params SqlParameter[] parameters)
        {
            using (var connection = Open())
            using (var command = new SqlCommand(sql, connection))
            {
                command.Parameters.AddRange(parameters);
                return command.ExecuteNonQuery();
            }
        }
    }
}
