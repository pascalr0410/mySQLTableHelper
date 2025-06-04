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

! UPDATE !

News version, more simple, stable and versatile, catch almost all possible case !

Here is the test function :

    struct testStruc
        a::Float64
        function testStruc() return new(rand()) end
    end

    function testDf() #Crash TEX !
        return DataFrame(
            a = 1:4, 
            b = ["M", "", missing, "MM"], 
            c = Date(2022), 
            d = [3.14, missing, NaN, -0.0],
            e = Time(1),
            f = DateTime(2022,1,1,0,0,1),
            g = missing, #usuported type
            h = [[1,"a", Main], Int64, x -> x + 1, DataFrame()], 
            i = [1, "a", 2, "b"],
            j = [true, false, true, false],
            k = Any[Int64(1), Float64(2.0), Int32(3), Real(4.33)],
            l = [testStruc(), testStruc(), testStruc(), missing]
        )
    end

    function test(;db::String = defaultDb,
            df::DataFrame = testDf(), 
            testTbl::String = "test_mySQLTableHelper",
            cnx::DBInterface.Connection = getCnx(db = db))::DataFrame

        createTable(df, testTbl, debug = true, cnx = cnx)
        
        addPk(testTbl, "a")
        addIdx(testTbl, ("a", "b", "c"))

        return getTable(testTbl, debug = true, cnx = cnx)
        
    end
