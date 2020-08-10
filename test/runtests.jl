using Test, Tables, TableTraits, DataValues, QueryOperators, IteratorInterfaceExtensions, SparseArrays, SplittablesBase, SplittablesTesting

@testset "utils.jl" begin

    @test getproperty((1, 2), 1) == 1

    NT = NamedTuple{(), Tuple{}}
    @test Tables.names(NT) === ()
    @test Tables.types(NT) === Tuple{}
    @test isempty(Tables.runlength(Tables.types(NT)))
    @test Tables.columnindex(Tables.names(NT), :i) == 0
    @test Tables.columntype(Tables.names(NT), Tables.types(NT), :i) == Union{}

    NT = NamedTuple{(:a, :b, :c), NTuple{3, Int64}}
    @test Tables.names(NT) === (:a, :b, :c)
    @test Tables.types(NT) === Tuple{Int64, Int64, Int64}
    @test Tables.runlength(Tables.types(NT)) == [(Int64, 3)]
    @test Tables.columnindex(Tables.names(NT), :a) == 1
    @test Tables.columnindex(Tables.names(NT), :i) == 0
    @test Tables.columntype(Tables.names(NT), Tables.types(NT), :a) == Int64
    @test Tables.columntype(Tables.names(NT), Tables.types(NT), :i) == Union{}

    NT = NamedTuple{Tuple(Symbol("a$i") for i = 1:20), Tuple{vcat(fill(Int, 10), fill(String, 10))...}}
    @test Tables.names(NT) === Tuple(Symbol("a$i") for i = 1:20)
    @test Tables.types(NT) === Tuple{vcat(fill(Int, 10), fill(String, 10))...}
    @test Tables.runlength(Tables.types(NT)) == [(Int, 10), (String, 10)]
    @test Tables.columnindex(Tables.names(NT), :a20) == 20
    @test Tables.columnindex(Tables.names(NT), :i) == 0
    @test Tables.columntype(Tables.names(NT), Tables.types(NT), :a20) == String
    @test Tables.columntype(Tables.names(NT), Tables.types(NT), :i) == Union{}

    nt = (a=1, b=2, c=3)
    NT = typeof(nt)
    output = [0, 0, 0]
    Tables.eachcolumn(Tables.Schema(Tables.names(NT), Tables.types(NT)), nt) do val, col, nm
        output[col] = val
    end
    @test output == [1, 2, 3]

    nt = NamedTuple{Tuple(Symbol("a$i") for i = 1:101)}(Tuple(i for i = 1:101))
    NT = typeof(nt)
    @test Tables.runlength(Tables.types(NT)) == [(Int, 101)]
    output = zeros(Int, 101)
    Tables.eachcolumn(Tables.Schema(Tables.names(NT), Tables.types(NT)), nt) do val, col, nm
        output[col] = val
    end
    @test output == [i for i = 1:101]

    nt = NamedTuple{Tuple(Symbol("a$i") for i = 1:101)}(Tuple(i % 2 == 0 ? i : "$i" for i = 1:101))
    NT = typeof(nt)
    @test Tables.runlength(Tables.types(NT)) == [i % 2 == 0 ? (Int, 1) : (String, 1) for i = 1:101]
    output = Vector{Any}(undef, 101)
    Tables.eachcolumn(Tables.Schema(Tables.names(NT), Tables.types(NT)), nt) do val, col, nm
        output[col] = val
    end
    @test output == [i % 2 == 0 ? i : "$i" for i = 1:101]

    nt = (a=Ref(0), b=Ref(0))
    Tables.eachcolumn(Tables.Schema((:a, :b), nothing), (a=1, b=2)) do val, col, nm
        nt[nm][] = val
    end
    @test nt.a[] == 1
    @test nt.b[] == 2

    nt = (a=[1,2,3], b=[4,5,6])
    @test Tables.columnindex(nt, :i) == 0
    @test Tables.columnindex(nt, :a) == 1
    @test Tables.columntype(nt, :a) == Int
    @test Tables.columntype(nt, :i) == Union{}

    rows = Tables.rows(nt)
    @test eltype(rows) == Tables.ColumnsRow{typeof(nt)}
    @test Tables.schema(rows) == Tables.Schema((:a, :b), (Int, Int))
    @test rows.a == [1,2,3]
    @test propertynames(rows) == Tables.columnnames(rows) == (:a, :b)
    row = first(rows)
    @test row.a == 1
    @test Tables.getcolumn(row, :a) == 1
    @test Tables.getcolumn(row, 1) == 1
    @test Tables.istable(rows)
    @test Tables.rowaccess(rows)
    @test Tables.rows(rows) === rows
    @test Tables.columnaccess(rows)
    @test Tables.columns(rows) === nt
    @test Tables.materializer(rows) === Tables.materializer(nt)

    @test Tables.sym(1) === 1
    @test Tables.sym("hey") == :hey

    @test propertynames(Tables.Schema((:a, :b), nothing)) == (:names, :types)

    v = Tables.EmptyVector(1)
    @test_throws UndefRefError v[1]
    @test Base.IndexStyle(typeof(v)) == Base.IndexLinear()

    @test Tables.istable(Tables.CopiedColumns)
    @test Tables.columnaccess(Tables.CopiedColumns)
    c = Tables.CopiedColumns(nt)
    @test Tables.columns(c) === c
    @test Tables.materializer(c) == Tables.materializer(nt)
    @test Tables.getcolumn(c, :a) == [1,2,3]
    @test Tables.getcolumn(c, 1) == [1,2,3]

    @test_throws ArgumentError Tables.columntable([1,2,3])

    tt = [(1,2,3), (4,5,6)]
    r = Tables.nondatavaluerows(tt)
    row = first(r)
    @test getproperty(row, 1) == 1
    @test Tables.columntable(tt) == NamedTuple{(Symbol("1"), Symbol("2"), Symbol("3"))}(([1, 4], [2, 5], [3, 6]))

    @test Tables.getarray([1,2,3]) == [1,2,3]
    @test Tables.getarray((1,2,3)) == [1,2,3]
end

@testset "namedtuples.jl" begin

    nt = (a=1, b=2, c=3)
    rt = [nt, nt, nt]
    @test Tables.rows(rt) === rt
    @test Tables.schema(rt).names == Tables.names(typeof(nt))
    @test Tables.namedtupleiterator(eltype(rt), rt) === rt

    rt = [(a=1, b=4.0, c="7"), (a=2, b=5.0, c="8"), (a=3, b=6.0, c="9")]
    nt = (a=[1,2,3], b=[4.0, 5.0, 6.0], c=["7", "8", "9"])
    @test Tables.rowcount(nt) == 3
    @test Tables.schema(nt) == Tables.Schema((:a, :b, :c), Tuple{Int, Float64, String})
    @test Tables.istable(typeof(nt))
    @test Tables.columnaccess(typeof(nt))
    @test Tables.columns(nt) === nt
    @test rowtable(nt) == rt
    @test columntable(rt) == nt
    @test rt == (rt |> columntable |> rowtable)
    @test nt == (nt |> rowtable |> columntable)

    @test Tables.buildcolumns(nothing, rt) == nt
    @test Tables.columntable(nothing, nt) == nt

    # test push!
    rtf = Iterators.Filter(x->x.a >= 1, rt)
    @test Tables.columntable(rtf) == nt
    @test Tables.buildcolumns(nothing, rtf) == nt

    rt = [(a=1, b=4.0, c="7"), (a=2.0, b=missing, c="8"), (a=3, b=6.0, c="9")]
    @test Tables.istable(typeof(rt))
    @test Tables.rowaccess(typeof(rt))
    tt = Tables.buildcolumns(nothing, rt)
    @test isequal(tt, (a = [1.0, 2.0, 3.0], b = Union{Missing, Float64}[4.0, missing, 6.0], c = ["7", "8", "9"]))
    @test tt.a[1] === 1.0
    @test tt.a[2] === 2.0
    @test tt.a[3] === 3.0

    nti = Tables.NamedTupleIterator{Nothing, typeof(rt)}(rt)
    @test Base.IteratorEltype(typeof(nti)) == Base.EltypeUnknown()
    @test Base.IteratorSize(typeof(nti)) == Base.HasShape{1}()
    @test length(nti) == 3
    nti2 = collect(nti)
    @test isequal(rt, nti2)
    nti = Tables.NamedTupleIterator{typeof(Tables.Schema((:a, :b, :c), (Union{Int, Float64}, Union{Float64, Missing}, String))), typeof(rt)}(rt)
    @test eltype(typeof(nti)) == NamedTuple{(:a, :b, :c),Tuple{Union{Float64, Int},Union{Missing, Float64},String}}

    # test really wide tables
    nms = Tuple(Symbol("i", i) for i = 1:101)
    vals = Tuple(rand(Int, 3) for i = 1:101)
    nt = NamedTuple{nms}(vals)
    rt = Tables.rowtable(nt)
    @test length(rt) == 3
    @test length(rt[1]) == 101
    @test eltype(rt).parameters[1] == nms
    @test Tables.columntable(rt) == nt
    @test Tables.buildcolumns(nothing, rt) == nt
end

@testset "Materializer" begin 
    rt = [(a=1, b=4.0, c="7"), (a=2, b=5.0, c="8"), (a=3, b=6.0, c="9")]
    nt = (a=[1,2,3], b=[4.0, 5.0, 6.0], c=["7", "8", "9"])

    @test nt == Tables.materializer(nt)(Tables.columns(nt))
    @test nt == Tables.materializer(nt)(Tables.columns(rt))
    @test nt == Tables.materializer(nt)(rt)
    @test rt == Tables.materializer(rt)(nt)

    function select(table, cols::Symbol...)
        Tables.istable(table) || throw(ArgumentError("select requires a table input"))
        nt = Tables.columntable(table)  # columntable(t) creates a NamedTuple of AbstractVectors
        newcols = NamedTuple{cols}(nt)
        Tables.materializer(table)(newcols)
    end

    @test select(nt, :a, :b, :c) == nt
    @test select(nt, :c, :a) == NamedTuple{(:c, :a)}(nt)
    @test select(rt, :a) == [(a=1,), (a=2,), (a=3,)]

    @test Tables.materializer(1) === Tables.columntable
end

@testset "Matrix integration" begin
    rt = [(a=1, b=4.0, c="7"), (a=2, b=5.0, c="8"), (a=3, b=6.0, c="9")]
    nt = (a=[1,2,3], b=[4.0, 5.0, 6.0])

    mat = Tables.matrix(rt)
    @test nt.a == mat[:, 1]
    @test size(mat) == (3, 3)
    @test eltype(mat) == Any
    @test_throws ArgumentError Tables.rows(mat)
    @test_throws ArgumentError Tables.columns(mat)
    mat2 = Tables.matrix(nt)
    @test eltype(mat2) == Float64
    @test mat2[:, 1] == nt.a
    @test !Tables.istable(mat2)
    @test !Tables.istable(typeof(mat2))
    mat3 = Tables.matrix(nt; transpose=true)
    @test size(mat3) == (2, 3)
    @test mat3[1, :] == nt.a
    @test mat3[2, :] == nt.b
    sp = Tables.table(sparse(mat[:, 1:2]))
    @test Tables.columnnames(sp) == [:Column1, :Column2]
    @test Tables.getcolumn(sp, 1) == [1, 2, 3]

    tbl = Tables.table(mat) |> columntable
    @test keys(tbl) == (:Column1, :Column2, :Column3)
    @test tbl.Column1 == [1, 2, 3]
    tbl2 = Tables.table(mat2) |> rowtable
    @test length(tbl2) == 3
    @test map(x->x.Column1, tbl2) == [1.0, 2.0, 3.0]

    mattbl = Tables.table(mat)
    @test Tables.istable(typeof(mattbl))
    @test Tables.rowaccess(typeof(mattbl))
    @test Tables.rows(mattbl) === mattbl
    @test Tables.columnaccess(typeof(mattbl))
    @test Tables.columns(mattbl) === mattbl
    @test mattbl.Column1 == [1,2,3]
    @test Tables.getcolumn(mattbl, :Column1) == [1,2,3]
    @test Tables.getcolumn(mattbl, 1) == [1,2,3]
    matrow = first(mattbl)
    @test eltype(mattbl) == typeof(matrow)
    @test matrow.Column1 == 1
    @test Tables.getcolumn(matrow, :Column1) == 1
    @test Tables.getcolumn(matrow, 1) == 1
    @test propertynames(mattbl) == propertynames(matrow) == [:Column1, :Column2, :Column3]

    # #155
    m = hcat([1,2,3],[1,2,3])
    T = Tables.table(m)
    M = Tables.matrix(T)
    Mt = Tables.matrix(T, transpose=true)
    @test M[:, 1] == [1, 2, 3]
    # 182
    @test M === m #checks that both are the same object in memory
    @test Mt == permutedims(m) 
    # 167
    @test !Tables.istable(Matrix{Union{}}(undef, 2, 3))
end

import Base: ==
struct GenericRow
    a::Int
    b::Float64
    c::String
end
==(a::GenericRow, b::GenericRow) = a.a == b.a && a.b == b.b && a.c == b.c

struct GenericRowTable
    data::Vector{GenericRow}
end
==(a::GenericRowTable, b::GenericRowTable) = all(a.data .== b.data)

Base.eltype(g::GenericRowTable) = GenericRow
Base.length(g::GenericRowTable) = length(g.data)
Base.size(g::GenericRowTable) = (length(g.data),)
Tables.istable(::Type{GenericRowTable}) = true
Tables.rowaccess(::Type{GenericRowTable}) = true
Tables.rows(x::GenericRowTable) = x
Tables.schema(x::GenericRowTable) = Tables.Schema((:a, :b, :c), Tuple{Int, Float64, String})

function Base.iterate(g::GenericRowTable, st=1)
    st > length(g.data) && return nothing
    return g.data[st], st + 1
end

genericrowtable(x) = GenericRowTable(collect(map(x->GenericRow(x.a, x.b, x.c), Tables.rows(x))))

struct GenericColumn{T} <: AbstractVector{T}
    data::Vector{T}
end
Base.eltype(g::GenericColumn{T}) where {T} = T
Base.length(g::GenericColumn) = length(g.data)
==(a::GenericColumn, b::GenericColumn) = a.data == b.data
Base.getindex(g::GenericColumn, i::Int) = g.data[i]

struct GenericColumnTable
    names::Dict{Symbol, Int}
    data::Vector{GenericColumn}
end

Tables.istable(::Type{GenericColumnTable}) = true
Tables.columnaccess(::Type{GenericColumnTable}) = true
Tables.columns(x::GenericColumnTable) = x
Tables.schema(g::GenericColumnTable) = Tables.Schema(Tuple(keys(getfield(g, 1))), Tuple{(eltype(x) for x in getfield(g, 2))...})
Base.getproperty(g::GenericColumnTable, nm::Symbol) = getfield(g, 2)[getfield(g, 1)[nm]]
Base.propertynames(g::GenericColumnTable) = Tuple(keys(getfield(g, 1)))

function genericcolumntable(x)
    cols = Tables.columns(x)
    sch = Tables.schema(x)
    data = [GenericColumn(getproperty(cols, nm)) for nm in sch.names]
    return GenericColumnTable(Dict(nm=>i for (i, nm) in enumerate(sch.names)), data)
end
==(a::GenericColumnTable, b::GenericColumnTable) = getfield(a, 1) == getfield(b, 1) && getfield(a, 2) == getfield(b, 2)

@testset "Tables.jl interface" begin

    @test !Tables.istable(1)
    @test !Tables.istable(Int)
    @test !Tables.rowaccess(1)
    @test !Tables.rowaccess(Int)
    @test !Tables.columnaccess(1)
    @test !Tables.columnaccess(Int)
    @test Tables.schema(1) === nothing

    sch = Tables.Schema{(:a, :b), Tuple{Int64, Float64}}()
    @test Tables.Schema((:a, :b), Tuple{Int64, Float64}) === sch
    @test Tables.Schema(NamedTuple{(:a, :b), Tuple{Int64, Float64}}) === sch
    @test Tables.Schema((:a, :b), nothing) === Tables.Schema{(:a, :b), nothing}()
    @test Tables.Schema([:a, :b], [Int64, Float64]) === sch
    show(sch)
    @test sch.names == (:a, :b)
    @test sch.types == (Int64, Float64)
    @test_throws ArgumentError sch.foobar

    gr = GenericRowTable([GenericRow(1, 4.0, "7"), GenericRow(2, 5.0, "8"), GenericRow(3, 6.0, "9")])
    gc = GenericColumnTable(Dict(:a=>1, :b=>2, :c=>3), [GenericColumn([1,2,3]), GenericColumn([4.0, 5.0, 6.0]), GenericColumn(["7", "8", "9"])])
    @test gc == (gr |> genericcolumntable)
    @test gr == (gc |> genericrowtable)
    @test gr == (gr |> genericrowtable)

    @test_throws ArgumentError Tables.columns(Int64)
    @test_throws ArgumentError Tables.rows(Int64)
end

@testset "isless" begin
    t = (x = [1, 1, 0, 2], y = [-1, 1, 3, 2])
    a,b,c,d = Tables.rows(t)
    @test isless(a, b)
    @test isless(c, d)
    @test !isless(d, a)
    @test !isequal(a, b)
    @test isequal(a, a)
    @test sortperm([a, b, c, d]) == [3, 1, 2, 4]
end

struct ColumnSource
end

TableTraits.supports_get_columns_copy_using_missing(::ColumnSource) = true

function TableTraits.get_columns_copy_using_missing(x::ColumnSource)
    return (a=[1,2,3], b=[4.,5.,6.], c=["A", "B", "C"])
end

let x=ColumnSource()
    @test Tables.source(Tables.columns(x)) == Tables.source(Tables.CopiedColumns(TableTraits.get_columns_copy_using_missing(x)))
end

struct ColumnSource2
end

IteratorInterfaceExtensions.isiterable(x::ColumnSource2) = true
TableTraits.isiterabletable(::ColumnSource2) = true

IteratorInterfaceExtensions.getiterator(::ColumnSource2) =
    Tables.rows((a=[1,2,3], b=[4.,5.,6.], c=["A", "B", "C"]))

let x=ColumnSource2()
    @test Tables.source(Tables.columns(x)) == (a=[1,2,3], b=[4.,5.,6.], c=["A", "B", "C"])
end

@testset "TableTraits integration" begin
    rt = (a = Real[1, 2.0, 3], b = Union{Missing, Float64}[4.0, missing, 6.0], c = ["7", "8", "9"])

    dv = Tables.datavaluerows(rt)
    @test Base.IteratorSize(typeof(dv)) == Base.HasLength()
    @test eltype(dv) == NamedTuple{(:a, :b, :c),Tuple{Real,DataValue{Float64},String}}
    @test_throws MethodError size(dv)
    rt2 = collect(dv)
    @test rt2[1] == (a = 1, b = DataValue{Float64}(4.0), c = "7")

    ei = Tables.nondatavaluerows(QueryOperators.EnumerableIterable{eltype(dv), typeof(dv)}(dv))
    @test Tables.istable(typeof(ei))
    @test Tables.rowaccess(typeof(ei))
    @test Tables.rows(ei) === ei
    @test Base.IteratorEltype(typeof(ei)) == Base.HasEltype()
    @test Base.IteratorSize(typeof(ei)) == Base.HasLength()
    @test eltype(ei) == Tables.IteratorRow{NamedTuple{(:a, :b, :c),Tuple{Real,DataValue{Float64},String}}}
    @test eltype(typeof(ei)) == Tables.IteratorRow{NamedTuple{(:a, :b, :c),Tuple{Real,DataValue{Float64},String}}}
    @test_throws MethodError size(ei)
    nt = ei |> columntable
    @test isequal(rt, nt)
    rt3 = ei |> rowtable
    @test isequal(rt |> rowtable, rt3)

    # rt = [(a=1, b=4.0, c="7"), (a=2, b=5.0, c="8"), (a=3, b=6.0, c="9")]
    mt = Tables.nondatavaluerows(ei.x |> y->QueryOperators.map(y, x->(a=x.b, c=x.c), Expr(:block)))
    @inferred (mt |> columntable)
    @inferred (mt |> rowtable)

    # uninferrable case
    mt = Tables.nondatavaluerows(ei.x |> y->QueryOperators.map(y, x->(a=x.a, c=x.c), Expr(:block)))
    @test (mt |> columntable) == (a = Real[1, 2.0, 3], c = ["7", "8", "9"])
    @test length(mt |> rowtable) == 3

    rt = (a = Missing[missing, missing], b=[1,2])
    dv = Tables.datavaluerows(rt)
    @test eltype(dv) == NamedTuple{(:a, :b), Tuple{DataValue{Union{}}, Int}}

    # DataValue{Any}
    @test isequal(Tables.columntable(Tables.nondatavaluerows([(a=DataValue{Any}(), b=DataValue{Int}())])), (a = Any[missing], b = Union{Missing, Int64}[missing]))
end

@testset "AbstractDict" begin

    d = Dict(:a => 1, :b => missing, :c => "7")
    n = (a=1, b=missing, c="7")
    drt = [d, d, d]
    rt = [n, n, n]
    dct = Dict(:a => [1, 1, 1], :b => [missing, missing, missing], :c => ["7", "7", "7"])
    ct = (a = [1, 1, 1], b = [missing, missing, missing], c = ["7", "7", "7"])
    @test Tables.istable(drt)
    @test Tables.rowaccess(drt)
    @test Tables.rows(drt) === drt
    @test Tables.schema(drt) === nothing
    @test isequal(Tables.rowtable(drt), rt)
    @test isequal(Tables.columntable(drt), ct)

    @test Tables.istable(dct)
    @test Tables.columnaccess(dct)
    @test Tables.columns(dct) === dct
    @test Tables.schema(dct) == Tables.Schema((:a, :b, :c), Tuple{Int, Missing, String})
    @test isequal(Tables.rowtable(dct), rt)
    @test isequal(Tables.columntable(dct), ct)

    # a Dict w/ scalar values isn't a table
    @test_throws Exception Tables.columns(d)
end

struct Row <: Tables.AbstractRow
    a::Int
    b::Union{Float64, Missing}
    c::String
end

Tables.getcolumn(r::Row, i::Int) = getfield(r, i)
Tables.getcolumn(r::Row, nm::Symbol) = getfield(r, nm)
Tables.getcolumn(r::Row, ::Type{T}, i::Int, nm::Symbol) where {T} = getfield(r, i)
Tables.columnnames(r::Row) = fieldnames(Row)

@testset "AbstractRow" begin

    row = Row(1, missing, "hey")
    row2 = Row(2, 3.14, "ho")

    @test Base.IteratorSize(typeof(row)) == Base.HasLength()
    @test length(row) == 3
    @test firstindex(row) == 1
    @test lastindex(row) == 3
    @test isequal((row[1], row[2], row[3]), (1, missing, "hey"))
    @test isequal((row[:a], row[:b], row[:c]), (1, missing, "hey"))
    @test isequal((row.a, row.b, row.c), (1, missing, "hey"))
    @test isequal((getproperty(row, 1), getproperty(row, 2), getproperty(row, 3)), (1, missing, "hey"))
    @test propertynames(row) == (:a, :b, :c)
    @test keys(row) == (:a, :b, :c)
    @test isequal(values(row), [1, missing, "hey"])
    @test haskey(row, :a)
    @test haskey(row, 1)
    @test get(row, 1, 0) == get(row, :a, 0) == 1
    @test get(() -> 0, row, 1) == get(() -> 0, row, :a) == 1
    @test isequal(collect(row), [1, missing, "hey"])
    @test !isempty(row)
    @test isequal(NamedTuple(row), (a=1, b=missing, c="hey"))
    show(row)

    art = [row, row2]
    ct = (a=[1, 2], b=[missing, 3.14], c=["hey", "ho"])
    @test Tables.istable(art)
    @test Tables.rowaccess(art)
    @test Tables.rows(art) === art
    @test Tables.schema(art) === nothing
    @test isequal(Tables.columntable(art), ct)

end

struct Columns <: Tables.AbstractColumns
    a::Vector{Int}
    b::Vector{Union{Float64, Missing}}
    c::Vector{String}
end

Tables.getcolumn(r::Columns, i::Int) = getfield(r, i)
Tables.getcolumn(r::Columns, nm::Symbol) = getfield(r, nm)
Tables.getcolumn(r::Columns, ::Type{T}, i::Int, nm::Symbol) where {T} = getfield(r, i)
Tables.columnnames(r::Columns) = fieldnames(Columns)

@testset "AbstractColumns" begin

    col = Columns([1, 2], [missing, 3.14], ["hey", "ho"])

    @test Base.IteratorSize(typeof(col)) == Base.HasLength()
    @test length(col) == 3
    @test firstindex(col) == 1
    @test lastindex(col) == 3
    @test isequal((col[1], col[2], col[3]), ([1,2], [missing,3.14], ["hey","ho"]))
    @test isequal((col[:a], col[:b], col[:c]), ([1,2], [missing,3.14], ["hey","ho"]))
    @test isequal((col.a, col.b, col.c), ([1,2], [missing,3.14], ["hey","ho"]))
    @test isequal((getproperty(col, 1), getproperty(col, 2), getproperty(col, 3)), ([1,2], [missing,3.14], ["hey","ho"]))
    @test propertynames(col) == (:a, :b, :c)
    @test keys(col) == (:a, :b, :c)
    @test isequal(values(col), [[1,2], [missing,3.14], ["hey","ho"]])
    @test haskey(col, :a)
    @test haskey(col, 1)
    @test get(col, 1, 0) == get(col, :a, 0) == [1,2]
    @test get(() -> 0, col, 1) == get(() -> 0, col, :a) == [1,2]
    @test isequal(collect(col), [[1,2], [missing,3.14], ["hey","ho"]])
    show(col)

    ct = (a=[1, 2], b=[missing, 3.14], c=["hey", "ho"])
    @test Tables.istable(col)
    @test Tables.columnaccess(col)
    @test Tables.columns(col) === col
    @test Tables.schema(col) === nothing
    @test isequal(Tables.columntable(col), ct)
end

struct IsRowTable
    rows::Vector{NamedTuple}
end

Base.iterate(x::IsRowTable) = iterate(x.rows)
Base.iterate(x::IsRowTable, st) = iterate(x.rows, st)
Base.length(x::IsRowTable) = length(x.rows)

Tables.isrowtable(::Type{IsRowTable}) = true

@testset "Tables.isrowtable" begin

    nt = (a=1, b=3.14, c="hey")
    rt = IsRowTable([nt, nt, nt])
    @test Tables.istable(rt)
    @test Tables.rowaccess(rt)
    @test Tables.rows(rt) === rt
    @test Tables.columntable(rt) == Tables.columntable([nt, nt, nt])

end

@testset "SplittablesBase" begin
    nt4 = (a = [0, 1, 2, 3], b = [5, 6, 7, 8])
    nt5 = (a = [0, 1, 2, 3, 4], b = [5, 6, 7, 8, 9])
    nt0 = NamedTuple()
    SplittablesTesting.test_ordered([
        (label = "RowIterator (length = 4)", data = Tables.rows(nt4)),
        (label = "RowIterator (length = 5)", data = Tables.rows(nt5)),
        (label = "RowIterator (no columns)", data = Tables.RowIterator(nt0, 5)),
        (
            label = "NamedTupleIterator (length = 4)",
            data = Tables.namedtupleiterator(Tables.rows(nt4)),
        ),
        (
            label = "NamedTupleIterator (length = 5)",
            data = Tables.namedtupleiterator(Tables.rows(nt5)),
        ),
        (
            label = "NamedTupleIterator (no columns)",
            data = Tables.namedtupleiterator(Tables.RowIterator(nt0, 5)),
        ),
    ])

    @testset "Inconsistent `halve` of columns should throw" begin
        rt = Tables.rows((a = [0, 1, 2, 3, 4], b = [5, 6, 7, 8]))
        @test_throws(
            ArgumentError("`halve` on columns return inconsistent number or rows"),
            SplittablesBase.halve(rt)
        )
    end
end
