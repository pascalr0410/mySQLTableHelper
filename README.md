# mySQLTableHelper

Simple module to write a DataFrame into a mySql table in a fast, reliable and easy way.

This module assume the table creation and support String, Int64, Float64,
and Date data format and may be easily extended

Usage mySQLTableHelper.createTable(DataFrame, TargetTableName::String, MySQL.Connection)

Optional argument :

- dropIfExist::Bool=true -> set to false if you want to append to an existing table
- forceStringSize::Int64=-1 -> force to String size, if not set, size is automatically determined
Usefull if you want to append multiple dataframe into a single table

To avoid unicode integration problem, you should use the initCnxUtf8(MySQL.Connection) function
before using the createTable function to properly intialize utf8 string format of the DB connection.
