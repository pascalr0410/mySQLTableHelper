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

And the output !

julia> mySQLTableHelper.test()
createTableQuerry! a : Int64
createTableQuerry! b : Union{Missing, String}
createTableQuerry! c : Dates.Date
createTableQuerry! d : Union{Missing, Float64}
createTableQuerry! e : Dates.Time
createTableQuerry! f : Dates.DateTime
createTableQuerry! g : Missing
┌ Warning: `g` col is of type Missing back to Any
└ @ Main.mySQLTableHelper c:\Users\XXXXXX\mySQLTableHelper2.jl:93
┌ Warning: Unsupported type on field `g` : Any -> back to string
└ @ Main.mySQLTableHelper c:\Users\XXXXXX\mySQLTableHelper2.jl:141
createTableQuerry! h : Any
┌ Warning: Unsupported type on field `h` : Any -> back to string
└ @ Main.mySQLTableHelper c:\Users\XXXXXX\mySQLTableHelper2.jl:141
createTableQuerry! i : Any
┌ Warning: Unsupported type on field `i` : Any -> back to string
└ @ Main.mySQLTableHelper c:\Users\XXXXXX\mySQLTableHelper2.jl:141
createTableQuerry! j : Bool
┌ Warning: Must adapt `j` : Bool -> back to tiny int
└ @ Main.mySQLTableHelper c:\Users\XXXXXX\mySQLTableHelper2.jl:113
createTableQuerry! k : Any
┌ Warning: Float64 forced on mixed number type on col `k`
└ @ Main.mySQLTableHelper c:\Users\XXXXXX\mySQLTableHelper2.jl:136
createTableQuerry! l : Union{Missing, Main.mySQLTableHelper.testStruc}
┌ Warning: `l` type Main.mySQLTableHelper.testStruc has not being catched -> force to Any
└ @ Main.mySQLTableHelper c:\Users\XXXXXX\mySQLTableHelper2.jl:126
┌ Warning: Unsupported type on field `l` : Any -> back to string
└ @ Main.mySQLTableHelper c:\Users\XXXXXX\mySQLTableHelper2.jl:141
createTableQuerry! : CREATE TABLE `test_mySQLTableHelper` (`a` BIGINT, `b` VARCHAR(2), `c` DATE, `d` DOUBLE, `e` TIME, `f` DATETIME, `g` VARCHAR(0), `h` VARCHAR(17), `i` VARCHAR(1), `j` BOOL, `k` DOUBLE, `l` VARCHAR(51))
createTable Temp file : C:/Users/XXXXXX/AppData/Local/Temp/jl_q3odaruFul
createTable SQL Load : LOAD DATA LOCAL INFILE 'C:/Users/XXXXXX/AppData/Local/Temp/jl_q3odaruFul' INTO TABLE test_mySQLTableHelper CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"' IGNORE 1 LINES;        
execSql on db sandbox : SELECT * FROM test_mySQLTableHelper
4×12 DataFrame
 Row │ a      b        c           d           e         f                    g        h                  i        j      k         l
     │ Int64  String?  Date?       Float64?    Time?     DateTime?            String?  String?            String?  Int8?  Float64?  String?
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │     1  M        2022-01-01        3.14  01:00:00  2022-01-01T00:00:01  missing  Any[1, "a", Main]  1            1      1.0   Main.mySQLTableHelper.testStruc(…
   2 │     2           2022-01-01  missing     01:00:00  2022-01-01T00:00:01  missing  Int64              a            0      2.0   Main.mySQLTableHelper.testStruc(…
   3 │     3  missing  2022-01-01        0.0   01:00:00  2022-01-01T00:00:01  missing  #29                2            1      3.0   Main.mySQLTableHelper.testStruc(…
   4 │     4  MM       2022-01-01       -0.0   01:00:00  2022-01-01T00:00:01  missing  0×0 DataFrame      b            0      4.33  missing
