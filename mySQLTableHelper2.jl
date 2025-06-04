module mySQLTableHelper

    using DataFrames, Dates, MySQL, CSV, DBInterface
    export getCnx, createTable, getTable, execSql, showSessionVar, addPk, addIdx, setDefaultDb

    #------------------------------------------------------------------
    # this shoud be customised to fit your needs
    #------------------------------------------------------------------
    include("EnvVar.jl")
    mySSQLHost::String = env.key["MySQLHost"]
    MySQLUser::String = env.key["MySQLUser"]
    MySQLPass::String = env.key["MySQLPass"]
    defaultDb::String = "sandbox"
    #------------------------------------------------------------------

    function setDefaultDb(db::String = "")::String
        if db != "" global defaultDb = db end
        return defaultDb
    end

    function createTable(df::DataFrame, tableName::String; 
        dropIfExist::Bool = true, 
        db::String = defaultDb, 
        debug::Bool = false, 
        cnx::DBInterface.Connection = getCnx(db = db),
        kwargs...)

        #copie des chamùps, quasi neutre en terme de perf
        # mais permetra de faire des modif si nececessaire
        #pour les champs non pris en charge nativement
        dfm = DataFrame()
        for f in  propertynames(df)
            dfm[!, f] = df[!, f]
        end

        #supression et recréation de la table
        if dropIfExist
            DBInterface.execute(cnx, "DROP TABLE IF EXISTS `$tableName`;" )
            DBInterface.execute(cnx, createTableQuerry!(dfm, tableName; debug = debug, kwargs...))
        end

        #On zappe cette partie si il n'y a rien à insérer
        if nrow(dfm) == 0 return end

        #Création d'un fichier temporaire
        tempFile = replace(tempname(), "\\" => "/")
        CSV.write(tempFile, dfm, missingstring = "NULL")

        if debug println("createTable Temp file : $tempFile") end

        sqlLd = "LOAD DATA LOCAL INFILE '$tempFile' INTO TABLE $tableName " * 
            "CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' " * 
            "OPTIONALLY ENCLOSED BY '\"' ESCAPED BY '\"' IGNORE 1 LINES;"

        if debug println("createTable SQL Load : $sqlLd") end

        DBInterface.execute(cnx, sqlLd)

        #et on le vire
        if !debug rm(tempFile) end

    end

    #-------------------------------------------------------------------------------------------------------------------------------
    # Création de la requête de création de table
    # la fonction peux modifier le contenu du datafarame en cas de champs non pris en charge
    #-------------------------------------------------------------------------------------------------------------------------------
    function createTableQuerry!(df::DataFrame, tableName::String; debug = false, kw...)::String
        
        tblField::Vector{String} = []
        
        escapeName(name::Symbol)::String = "`$(strip(string(name)))`"

        for fn in propertynames(df)
            if debug println("createTableQuerry! $fn : $(eltype(df[!, fn]))") end
            push!(tblField, getSqlField(escapeName(fn), eltype(df[!, fn]); :df => df, :fn => fn, debug, kw...))
        end

        sqlCreate =  "CREATE TABLE `$tableName` ($(join(tblField, ", ")))"
        
        if debug println("createTableQuerry! : $sqlCreate") end

        return sqlCreate

    end

    #-------------------------------------------------------------------------------------------------------------------------------
    # gestion des format SQL en fonction des format des données
    #-------------------------------------------------------------------------------------------------------------------------------

    function getSqlField(name::String, dt::Type{Union{T, Missing}}; noWarn::Bool = false, kw...)::String where T
        if !(@isdefined T) 
            if !noWarn @warn "$name col is of type Missing back to Any" end
            return getSqlField(name, Any; noWarn, kw...) 
        end
        #if !noWarn @warn "$name type $dt recall with type $T" end
        return getSqlField(name, T; noWarn, kw...)
    end

    function getSqlField(name::String, dt::Type{T}; kw...)::String where T <:Integer
        return "$name BIGINT"
    end 

    function getSqlField(name::String, dt::Type{T}; kw...)::String where T <:Number
        return "$name DOUBLE"
    end 

    getSqlField(name::String, dt::Type{Date}; kw...)::String = "$name DATE"
    getSqlField(name::String, dt::Type{Time}; kw...)::String = "$name TIME"
    getSqlField(name::String, dt::Type{DateTime}; kw...)::String = "$name DATETIME"
    
    function getSqlField(name::String, dt::Type{Bool}; df::DataFrame, fn::Symbol, noWarn::Bool = false, kw...)::String 
        if !noWarn @warn "Must adapt $name : $(dt) -> back to tiny int" end
        df[!, fn] = map(x-> x ? 1 : 0, df[!, fn])
        return "$name BOOL"
    end
    
    #Tout les cast inconnu sont balancé en string
    Base.length(x::Missing) = 0
    getMaxLength(bod)::String = length(bod) == 0 ? "1" : string(max(map(x->length(x), bod)...))

    getSqlField(name::String, dt::Type{String}; df::DataFrame, fn::Symbol, kw...)::String = "$name VARCHAR($(getMaxLength(df[!, fn])))"

    #catch du n'importe quoi --> Any
    function getSqlField(name::String, dt::Type{T}; noWarn::Bool = false, kw...)::String where T <: Any 
        if !noWarn @warn "$name type $dt has not being catched -> force to Any" end
        return getSqlField(name, Any; noWarn, kw...)
    end

    # modifieur pour les type non supporté
    # !!! pas de point d'excalamtion car -> dans fonction amont
    function getSqlField(name::String, dt::Type{Any}; df::DataFrame, fn::Symbol, noWarn::Bool = false, kw...)::String
        
        #cas particulier pour des mix de type numérique
        if mapreduce(x -> typeof(x) <:Number, &, df[!, fn]) 
            if !noWarn @warn "Float64 forced on mixed number type on col $name" end
            df[!, fn] = map(x -> convert(Float64, x), df[!, fn])
            return getSqlField(name, Float64; :df => df, :fn => fn, noWarn, kw...)
        end

        if !noWarn @warn "Unsupported type on field $name : $(dt) -> back to string" end
        df[!, fn] = map(x-> x === missing ? missing : string(x), df[!, fn])
        return getSqlField(name, String; :df => df, :fn => fn, noWarn, kw...)
    end

    #------------------------------------------------------------------------
    #ultra Helper
    #------------------------------------------------------------------------

    showSessionVar(cnx::DBInterface.Connection)::DataFrame = DBInterface.execute(cnx, "SHOW SESSION VARIABLES;") |> DataFrame

    function getCnx(; db::String = defaultDb)::DBInterface.Connection

        cnx = DBInterface.connect(MySQL.Connection, mySSQLHost, MySQLUser, MySQLPass, db = db)

        DBInterface.execute(cnx, "set character_set_client='utf8mb4';")
        DBInterface.execute(cnx, "set character_set_connection='utf8mb4';")
        DBInterface.execute(cnx, "set character_set_results='utf8mb4';")
        DBInterface.execute(cnx, "set default_storage_engine='Aria';")

        return cnx

    end

    function execSql(sql::String; db::String = defaultDb, debug::Bool = false, cnx::DBInterface.Connection = getCnx(db = db))::DataFrame 
        cnx = getCnx(db = db)
        if debug println("execSql on db $db : $sql") end
        df = DBInterface.execute(cnx, sql) |> DataFrame
        DBInterface.close!(cnx)
        return df
    end

    function getTable(tblName::String; db::String = defaultDb, debug::Bool = false, cnx::DBInterface.Connection = getCnx(db = db))::DataFrame
        return execSql("SELECT * FROM $tblName", db = db, debug = debug, cnx = cnx)
    end

    function addPk(tblName::String, col::Union{String, Tuple{Vararg{String}}}; db::String = defaultDb, debug::Bool = false, cnx::DBInterface.Connection = getCnx(db = db))
        sqlCol = col isa Tuple ? join(col, ", ") : col
        return execSql("ALTER TABLE $db.$tblName ADD CONSTRAINT PK_$tblName PRIMARY KEY ($sqlCol);", db = db, debug = debug, cnx = cnx)
    end

    function addIdx(tblName::String, col::Union{String, Tuple{Vararg{String}}}; db::String = defaultDb, debug::Bool = false, cnx::DBInterface.Connection = getCnx(db = db))
        sqlCol = col isa Tuple ? join(col, ", ") : col
        idxName = col isa Tuple ? join(col, "_") : col
        return execSql("CREATE INDEX IDX_$idxName ON $db.$tblName($sqlCol);", db = db, debug = debug, cnx = cnx)
    end

    #------------------------------------------------------------------------

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

end
