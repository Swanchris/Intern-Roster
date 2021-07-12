using JuMP, Gurobi, DataFrames
import XLSX
roster = direct_model(Gurobi.Optimizer())

Intern = 1:12
Week = 1:52
Rotation = 1:21

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

# rotations = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21]
capacity  = [2,1,1,1,1,1,1,1,1, 1, 6, 1, 2, 2, 1, 1, 1, 1, 1,12, 1] # after week 5

early_cap = [2,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 4, 2, 1, 1, 2, 0, 0, 0] # weeks 1 to 4

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

## j=5,8,21

@variable(roster, g[Intern, [5,8,21]], Bin)

gen_med = @constraint(roster, [i in Intern],
        sum(x[i,k,j] for k in Week, j in [5,8,21]) == 7)
g_limiter = @constraint(roster, [j in [5,8,21]], sum(g[i,j] for i in Intern) == 4)
g_vars = @constraint(roster, [i in Intern], sum(g[i,j] for j in [5,8,21]) ==1)
gen_duration_dvar = @constraint(roster, [i in Intern, j in [5,8,21] ],
                sum(y[i,k,j] for k in 1:46) == g[i,j])
gen_durations = @constraint(roster, [i in Intern, k in 1:46, j in [5,8,21]],
                7*y[i,k,j] - sum(x[i, k + alpha, j] for alpha in 0:6 ) <= 0)


# j =19
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
                            sum(x[i,k,j] for k in Week, j in 14:18) >= 6)
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

Day = 1:5
WE = 1:2

@variables(roster, begin
    LATE[Intern, Week], Bin
    ADO[Intern, Week, Day], Bin
    TIL[Intern, Week, WE], Bin
    SEM[Intern, Week, WE], Bin
    WeC_1[Intern, Week, WE], Bin
    WeC_2[Intern, Week, WE], Bin
    WeD[Intern, Week, WE], Bin
    PubC[Intern, Week, Day], Bin
    PubD[Intern, Week, Day], Bin
end
)

Clay_weekend_limiter_1 = @constraint(roster, [k in Week, s in WE],
                        sum(WeC_1[i,k,s] for i in Intern) == 1)
Clay_weekend_limiter_2 = @constraint(roster, [k in Week, s in WE],
                        sum(WeC_2[i,k,s] for i in Intern) == 1)
Dan_weekend_limiter = @constraint(roster, [k in Week, s in WE],
                        sum(WeD[i,k,s] for i in Intern) == 1)

Single_Weekend_work_limiter = @constraint(roster, [i in Intern, k in Week],
                                sum(WeC_1[i,k,s] + WeC_2[i,k,s] + WeD[i,k,s] for s in WE) <= 1)

Total_Weekend_shifts_limit = @constraint(roster, [i in Intern],
                                sum(WeC_1[i,k,s] + WeC_2[i,k,s] + WeD[i,k,s] for k in Week,
                                s in WE) <= 26)

TIL_constraint = @constraint(roster, [i in Intern, k in 1:51, s in WE],
        WeC_1[i,k,s] + WeC_2[i,k,s] + WeD[i,k,s] - TIL[i,k+1,s] == 0)

@variable(roster, t[Intern, Week], Bin)

No_TIL_1 = @constraint(roster, [i in Intern, k in Week, d in WE, j in 12:13],
            TIL[i,k,d] - t[i,k] <= 0)
No_TIL_2 = @constraint(roster, [i in Intern, k in Week, d in WE, j in 12:13],
             x[i,k,j] + t[i,k]  <= 1)

ADOs_total = @constraint(roster, [i in Intern],
                sum(ADO[i,k,d] for k in 5:52, d in Day) == 12)
ADOs_none = @constraint(roster, sum(ADO[i,k,d] for i in Intern, k in 1:4, d in Day) == 0)

TIL_ADOs = @constraint(roster, [i in Intern, k in Week, d in WE],
            TIL[i,k,d] + ADO[i,k,d] <= 1)

SEM_ADOs = @constraint(roster, [i in Intern, k in Week, d in WE],
            SEM[i,k,d] + ADO[i,k,d] <= 1)

NoThursADO = @constraint(roster, sum(ADO[i,k,4] for i in Intern, k in Week) == 0)

SpacedOutADOS = @constraint(roster, [i in Intern, beta in 0:11],
                sum(ADO[i,5 + alpha + 4*beta, d] for d in Day, alpha in 0:3) == 1)

Late_Shift = @constraint(roster, [k in 5:52], sum(LATE[i, k] for i in Intern) == 1)

No_Early_Late = @constraint(roster, sum(LATE[i,k] for i in Intern, k in 1:4) == 0)

TIL_LATEs = @constraint(roster, [i in Intern, k in Week],
            sum(TIL[i,k,d] for d in WE) + LATE[i,k] <= 1)

ADO_LATEs = @constraint(roster, [i in Intern, k in Week],
            sum(ADO[i,k,d] for d in Day) + LATE[i,k] <= 1)

NLR = [3,5,6,7,8,9,10,12,13,15,16,17,18,19,20]

@variable(roster, n[Intern, Week], Bin)

LATE_at_Clay_1 = @constraint(roster, [i in Intern, k in Week],
                    LATE[i,k] - n[i,k] <= 0)
LATE_at_Clay_2 = @constraint(roster, [i in Intern, k in Week, j in NLR],
                    x[i,k,j] + n[i,k] <= 1)

Pub_Weeks = [4,11,15,16,17,24,39,44,52,52]
Pub_Days =  [3, 1, 5, 1, 1, 1, 5, 2, 1, 2]

Pub_Shifts_Clay = @constraint(roster, [(k,d) in zip(Pub_Weeks,Pub_Days)],
                    sum(PubC[i,k,d] for i in Intern) == 2)
Pub_Shifts_Dan = @constraint(roster, [(k,d) in zip(Pub_Weeks,Pub_Days)],
                    sum(PubD[i,k,d] for i in Intern) == 1)

NoPubADOs = @constraint(roster,
            sum(ADO[i,k,d] for i in Intern, (k,d) in zip(Pub_Weeks,Pub_Days)) == 0)

MaxPubWork = @constraint(roster, [i in Intern],
                sum( (PubC[i,k,d] + PubD[i,k,d]) for (k,d) in zip(Pub_Weeks,Pub_Days) ) <= 3)

Sem_Weeks = [7,7,22,22,29,29,39,39]
Sem_Days =  [1,2, 1, 2, 1, 2, 1, 2]

Seminars = @constraint(roster,
            sum(SEM[i,k,d] for i in Intern, (k,d) in zip(Sem_Weeks,Sem_Days)) == 96)

C = @expression(roster,
    sum( (PubC[i,k,d] + PubD[i,k,d] + SEM[i,k,s] + ADO[i,k,d] + LATE[i,k] + TIL[i,k,s])
    for i in Intern, k in Week, d in Day, s in WE ))

obj = @objective(roster, Min, z + C)

optimize!(roster)

#_________________________________________________________________________

out = sum((j*Matrix(JuMP.value.(x[:,:,j]))) for j in 1:21)
Names = ["IP", "MCH", "AP", "MIC", "CPDan-G", "CPDan-V", "CPDan-MH",
    "CPCas-G", "CPMoor", "CPKing", "CPClay", "HOMR/AAC", "QUM", "Disp-Clay", "Disp-Dan",
    "Disp-King", "Disp-Moor", "Disp-Cas", "CPCas-ED", "AL", "CPClay-G"]
Nums = string.(collect(1:21))
df = string.(convert.(Int64, round.(out)))
for j in 1:21
    replace!(df, Nums[j] => Names[j])
end
list = convert(Array{Int64},transpose([i for i in 1:52]))

XLSX.openxlsx("output/2022_roster.xlsx", mode="w") do xf
    sheet = xf[1]
    XLSX.rename!(sheet, "Year")
    sheet["B1:BA1"] = list
    sheet["B4:BA15"] = df
end

#_________________________________________________________________________

clay1 = sum((i*Matrix(JuMP.value.(WeC_1[i,:,:]))) for i in 1:12)
clay2 = sum((i*Matrix(JuMP.value.(WeC_2[i,:,:]))) for i in 1:12)
dan1 = sum((i*Matrix(JuMP.value.(WeD[i,:,:]))) for i in 1:12)
Weekend_roster = zeros(Float64,3,104)
Weekend_roster[:]
for i in 0:51
    Weekend_roster[6*i+1] = clay1[i+1]
    Weekend_roster[6*i+2] = clay2[i+1]
    Weekend_roster[6*i+3] = dan1[i+1]
    Weekend_roster[6*i+4] = clay1[i+53]
    Weekend_roster[6*i+5] = clay2[i+53]
    Weekend_roster[6*i+6] = dan1[i+53]
end

Weekend_roster = convert.(Int64, round.(Weekend_roster))

XLSX.openxlsx("output/2022_roster.xlsx", mode="rw") do xf
    XLSX.addsheet!(xf, "Weekends")
    sheet = xf[2]
    sheet["B4:DA6"] = Weekend_roster
end

#_________________________________________________________________________

ados = []
for i in 1:12
    push!(ados, convert.(Int64, round.(i*Matrix(JuMP.value.(ADO[i,:,:])))))
end
ados

for i in 1:12
    ados[i]


til =[]
for i in 1:12
    push!(til, convert.(Int64, round.(i*Matrix(JuMP.value.(TIL[i,:,:])))))
end
til

late = convert.(Int64, round.(sum((i*Array(JuMP.value.(LATE[i,:]))) for i in 1:12)))



CLAY = convert.(Int64, round.(clay))
dan= sum((i*Matrix(JuMP.value.(WeD[i,:,:]))) for i in 1:12)
DAN = convert.(Int64, round.(dan))



println(JuMP.value.(WeC[:,:,:]))
println(JuMP.value.(WeD[:,:,:]))




# using SparseArrays, DataFrames, CSV
#
# df2 = DataFrame(out)
#
# CSV.write("2022/2022_V1_raw.csv", df2)
#
# print(g)
#
# df = CSV.read("2022/2022_V1_raw.csv")
#
# convert(Matrix, df)
#
# df4
