using JuMP, Gurobi
import XLSX
roster = direct_model(Gurobi.Optimizer())

Intern = 1:12
Week = 1:52
Rotation = 1:20

@variables(roster, begin
    x[Intern, Week, Rotation], Bin
    y[Intern, Week, Rotation], Bin
    L[1:4, Week], Bin
end
)

# Leave _________________________________________________________________________

Four_weeks = @constraint(roster, [i in Intern],
            sum(x[i,k,20] for k in Week) - 4 ==0)

Staggered_leave = @constraint(roster, [i in Intern, (b,d) in zip([17:22, 34:40, 47:52], [1,1,2])],
                    sum(x[i, k , 20] for k in b) == d)


Third_week_dvar = @constraint(roster, [i in Intern],
                    sum(y[i,k,20] for k in 47:51) -1 ==0 )

Third_week_block = @constraint(roster, [i in Intern, k in 47:51],
                    2*y[i, k, 20] - sum(x[i, k + alpha, 20] for alpha in 0:1) <= 0)


# Physical Constraint _________________________________________________________________________

physical = @constraint(roster, [i in Intern, k in Week], sum(x[i,k,j] for j in Rotation) -1 ==0)

# Rotations  _________________________________________________________________________

rotations = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]
capacity  = [2,1,1,1,1,1,1,1,1, 1, 6, 1, 1, 2, 1, 1, 1, 1, 1,12] # after week 5

early_cap = [2,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 4, 2, 1, 1, 2, 0, 0] # weeks 1 to 4

Rotation_capacities_early = @constraint(roster, [(j,d) in zip(Rotation, early_cap), k in 1:4],
                        sum(x[i,k,j] for i in Intern) <= d)

Rotation_capacities_early = @constraint(roster, [(j,d) in zip(Rotation, capacity), k in 5:52],
                        sum(x[i,k,j] for i in Intern) <= d)

# Rotation completion _________________________________________________________________________

## j = 1
inpatients = @constraint(roster, [i in Intern], sum(x[i,k,1] for k in Week) >= 5)
inpatients_early = @constraint(roster, [i in Intern], sum(x[i,k,1] for k in 1:6) >= 1)
inpatients_mid = @constraint(roster, [i in Intern], sum(x[i,k,1] for k in 1:18) >= 2)

## j=2
MCH = @constraint(roster, [i in Intern], sum(x[i,k,2] for k in Week) >= 2)
MCH_dvar = @constraint(roster, [i in Intern], sum(y[i,k,2] for k in 5:51) ==1)
MCH_block = @constraint(roster, [i in Intern, k in 5:51],
            2*y[i,k,2] - sum(x[i,k + alpha, 2] for alpha in 0:1) <= 0)

## j=3
AP = @constraint(roster, [i in Intern], sum(x[i,k,3] for k in Week) == 3)
AP_dvar = @constraint(roster, [i in Intern], sum(y[i,k,3] for k in 5:35) == 1)
AP_block = @constraint(roster, [i in Intern, k in 5:35],
                2*y[i,k,3] - sum(x[i,k + alpha, 3] for alpha in 0:1) <= 0)
AP_third = @constraint(roster,[i in Intern], sum(x[i,k,3] for k in 37:52) == 1)

## j=4
MIC = @constraint(roster, [i in Intern], sum(x[i,k,4] for k in Week) ==4)
MIC_1_dvar = @constraint(roster, [i in Intern], sum(y[i,k,4] for k in 5:27 ) == 1)
MIC_2_dvar = @constraint(roster, [i in Intern], sum(y[i,k,4] for k in 29:51 ) == 1)
MIC = @constraint(roster, [ i in Intern, k in 5:27],
    2 - sum(x[i, k + alpha, 4] for alpha in 0:1 ) <= 2*(1-y[i,k,4]))
MIC = @constraint(roster, [ i in Intern, k in 29:51],
    2 - sum(x[i, k + alpha, 4] for alpha in 0:1 ) <= 2*(1-y[i,k,4]))

## j=5,8,19
gen_med_ed = @constraint(roster, [i in Intern],
        sum(x[i,k,j] for k in Week, j in [5,8,19]) == 9)
@variable(roster, g[Intern, [5,8]], Bin)
g_vars = @constraint(roster, [i in Intern], sum(g[i,m] for m in [5,8]) ==1)
gen_duration_dvar = @constraint(roster, [(b,d) in zip([5,8],[6,7]), i in Intern],
                sum(y[i,k,b] for k in 1:(52 - (d-1) ) ) == g[i,b])
gen_limit_5 = @constraint(roster, [i in Intern],
                sum(x[i,k,5] for k in Week) == 6*g[i,5])
gen_limit_8 = @constraint(roster, [i in Intern],
                sum(x[i,k,8] for k in Week) == 7*g[i,8] + g[i,5])
gen_durations = @constraint(roster, [(b,d) in zip([5,8],[6,7]),
                i in Intern, k in 1:(52 - (d-1) )],
                d - sum(x[i, k + alpha, b] for alpha in 0:(d-1) ) <= d*(1-y[i,k,b]))
ed_with_gen = @constraint(roster, [i in Intern, k in 5:50], y[i,k,19] - x[i,k-1,8] - x[i,k+2,8]
            <= (1-g[i,5]))

#ed
ed = MentalHealth = @constraint(roster, [i in Intern], sum(x[i,k,19] for k in Week) ==2)
ed_dvar = @constraint(roster, [i in Intern], sum(y[i,k,19] for k in 5:50) == 1)
ed_dur = @constraint(roster, [i in Intern, k in 5:50],
                2 - sum(x[i,k + alpha, 19] for alpha in 0:1) <= 2*(1-y[i,k,19]))

# j =6
Vasc = @constraint(roster, [i in Intern], sum(x[i,k,6] for k in Week) ==4)
Vasc_dvar = @constraint(roster, [i in Intern], sum(y[i,k,6] for k in 5:49) == 1)
Vasc_block = @constraint(roster, [i in Intern, k in 5:49],
                4*y[i,k,6] - sum(x[i,k + alpha, 6] for alpha in 0:3) <= 0)

# j =7
MentalHealth = @constraint(roster, [i in Intern], sum(x[i,k,7] for k in Week) >=2)
MentalHealth_dvar = @constraint(roster, [i in Intern], sum(y[i,k,7] for k in 5:51) ==1)
MentalHealth_block = @constraint(roster, [i in Intern, k in 5:51],
                        2*y[i,k,7] - sum(x[i,k + alpha, 7] for alpha in 0:1) <= 0)

# j =9,10
CPSmallSites = @constraint(roster, [i in Intern, j in 9:10],
                sum(x[i,k,j] for k in Week) >=3)
CPSmallSites_dvar = @constraint(roster, [i in Intern, j in 9:10], sum(y[i,k,j] for k in 5:50) ==1)
CPSmallSites_block = @constraint(roster, [i in Intern, j in 9:10, k in 5:50],
                        3*y[i,k,j] - sum(x[i,k + alpha, j] for alpha in 0:2) <= 0)

# j=11
Clayton = @constraint(roster, [i in Intern], sum(x[i,k,11] for k in Week) >=4)
Clayton_2 = @constraint(roster, [i in Intern], sum(x[i,k,11] for k in 1:25) ==0)
Clayton_dvar = @constraint(roster, [i in Intern], sum(y[i,k,11] for k in 26:49) ==1)
Clayton_block = @constraint(roster, [i in Intern, k in 26:49],
                4*y[i,k,11] - sum(x[i,k + alpha, 11] for alpha in 0:3) <= 0)

# j=12
HOMR = @constraint(roster, [i in Intern], sum(x[i,k,12] for k in Week) ==1)
HOMR_2 = @constraint(roster, [i in Intern], sum(x[i,k,12] for k in 5:30) ==1)

# j =13
qum_1 = @constraint(roster, [i in Intern], sum(x[i,k,13] for k in 5:21) >= 1)
qum_2 = @constraint(roster, [i in Intern], sum(x[i,k,13] for k in 1:39) == 2)

# j = {14,18}
Disp = @constraint(roster, [i in Intern],
                            sum(x[i,k,j] for k in Week, j in 14:18) >= 5)
Disp_early_all = @constraint(roster, [i in Intern],
                    sum(x[i,k,j] for k in 1:4, j in 14:18) >= 3)
Disp_early_clay = @constraint(roster, [i in Intern], sum(x[i,k,14] for k in 1:4) <= 2)
Disp_early_rest = @constraint(roster, [i in Intern, j in 15:18],
                    sum(x[i,k,j] for k in 1:4) <=1)

# objective
restricted = [4,7,11,15,16,22,24,29,39,44,52]

z = @expression(roster, sum(x[i,k,j] for i in Intern, j in 12:13, k in restricted)
                - sum(x[i,k,j] for i in Intern, j in 14:18, k in 1:6))
# z = @expression(roster, sum(x[i,k,j] for i in Intern, j in Rotation, k in Week))

obj_z = @objective(roster, Min, z)

optimize!(roster)

g = sum((i*Matrix(JuMP.value.(x[:,:,i]))) for i in 1:20)
Names = ["IP", "MCH", "AP", "MIC", "CPDan-G", "CPDan-V", "CPDan-MH",
    "CPCas-G", "CPMoor", "CPKing", "CPClay", "HOMR/AAC", "QUM", "Disp-Clay", "Disp-Dan",
    "Disp-King", "Disp-Moor", "Disp-Cas", "CPCas-ED", "AL"]
Nums = string.(collect(1:20))
df = string.(convert.(Int64, round.(g)))
for i in 1:20
    replace!(df, Nums[i] => Names[i])
end
list = convert(Array{Int64},transpose([i for i in 1:52]))
XLSX.openxlsx("output/2022_V1_0607_11.33.xlsx", mode="w") do xf
    sheet = xf[1]
    sheet["B1:BA1"] = list
    sheet["B4:BA15"] = df
end


using SparseArrays, DataFrames, CSV

df2 = DataFrame(g)

CSV.write("2022/2022_V1_raw.csv", df2)

print(g)

df = CSV.read("2022/2022_V1_raw.csv")

convert(Matrix, df)

df4
