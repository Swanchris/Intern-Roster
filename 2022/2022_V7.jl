using JuMP, Gurobi, DataFrames
import XLSX
roster = direct_model(Gurobi.Optimizer())

Intern = 1:12
Week = 1:52
Rotation = 1:21

@variables(roster, begin
    x[Intern, Week, Rotation], Bin
    y[Intern, Week, Rotation], Bin
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

#cover all other scenarios:
# leave_dvar = @constraint(roster, [i in Intern, k in Week],
#                     y[i,k,20] - x[i,k,20] == 0)

# Physical Constraint _________________________________________________________________________

physical = @constraint(roster, [i in Intern, k in Week], sum(x[i,k,j] for j in Rotation) -1 ==0)

# Rotations  _________________________________________________________________________

rotations = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21]
capacity  = [2,1,1,1,1,1,1,1,1, 1, 6, 1, 2, 2, 1, 1, 1, 1, 1,12, 1] # after week 5

early_cap = [2,0,0,0,0,0,0,0,0, 0, 0, 0, 0, 4, 2, 1, 1, 2, 0, 0, 0] # weeks 1 to 4

Rotation_capacities_early = @constraint(roster, [(j,d) in zip(Rotation, early_cap), k in 1:4],
                        sum(x[i,k,j] for i in Intern) <= d)

Rotation_capacities = @constraint(roster, [(j,d) in zip(Rotation, capacity), k in 5:52],
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
        sum(x[i,k,j] for k in 18:52, j in [5,8,21]) == 7)
g_limiter = @constraint(roster, [j in [5,8,21]], sum(g[i,j] for i in Intern) == 4)
g_vars = @constraint(roster, [i in Intern], sum(g[i,j] for j in [5,8,21]) ==1)
gen_duration_dvar = @constraint(roster, [i in Intern, j in [5,8,21] ],
                sum(y[i,k,j] for k in 18:46) == g[i,j])
gen_durations = @constraint(roster, [i in Intern, k in 18:46, j in [5,8,21]],
                7*y[i,k,j] - sum(x[i, k + alpha, j] for alpha in 0:6 ) <= 0)


# j =19
ed = @constraint(roster, [i in Intern], sum(x[i,k,19] for k in Week) ==2)
ed_dvar = @constraint(roster, [i in Intern], sum(y[i,k,19] for k in 5:51) == 1)
ed_dur = @constraint(roster, [i in Intern, k in 5:51],
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

#no qum / homr in certain weeks
qum_constraint1 = @constraint(roster, sum(x[i,k,j] for i in Intern, j in 12:13, k in restricted) == 0)

z = @expression(roster, - sum(x[i,k,j] for i in Intern, j in 14:18, k in 1:6))
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
    PubC_1[Intern, Week, Day], Bin
    PubC_2[Intern, Week, Day], Bin
    PubD[Intern, Week, Day], Bin
end
)

Clay_weekend_limiter_1 = @constraint(roster, [k in Week, s in WE],
                        sum(WeC_1[i,k,s] for i in Intern) == 1)
Clay_weekend_limiter_2 = @constraint(roster, [k in Week, s in WE],
                        sum(WeC_2[i,k,s] for i in Intern) == 1)
Dan_weekend_limiter = @constraint(roster, [k in Week, s in WE],
                        sum(WeD[i,k,s] for i in Intern) == 1)

No_Three_Weekends_in_a_row = @constraint(roster, [i in Intern, k in 1:50],
                        sum(WeC_1[i,k,s] + WeC_2[i,k,s] + WeD[i,k,s] +
                        WeC_1[i,k+1,s] + WeC_2[i,k+1,s] + WeD[i,k+1,s] +
                        WeC_1[i,k+2,s] + WeC_2[i,k+2,s] + WeD[i,k+2,s] for s in WE) <= 2)


Single_Weekend_work_limiter = @constraint(roster, [i in Intern, k in Week],
                                sum(WeC_1[i,k,s] + WeC_2[i,k,s] + WeD[i,k,s] for s in WE) <= 1)

Total_Weekend_shifts_limit = @constraint(roster, [i in Intern],
                                sum(WeC_1[i,k,s] + WeC_2[i,k,s] + WeD[i,k,s] for k in Week,
                                s in WE) <= 26)

Weekend_orien_1 = @constraint(roster, [i in Intern],
                    sum(WeC_1[i,k,s] for k in 1:5, s in WE)
                    + sum(PubC_1[i,k,d] for k in 1:5,d in Day) + WeC_1[i,6,1] == 1)
Weekend_orien_2 = @constraint(roster, [i in Intern],
                    sum(WeC_2[i,k,s] for k in 1:5, s in WE)
                    + sum(PubC_2[i,k,d] for k in 1:5,d in Day) + WeC_2[i,6,1] == 1)
Weekend_orien_3 = @constraint(roster, [i in Intern],
                    sum(WeD[i,k,s] for k in 1:5, s in WE)
                    + sum(PubD[i,k,d] for k in 1:5,d in Day) + WeD[i,6,1] == 1)

### Weekend_bastardisation
a_1 = [2*i-1 for i in 1:6]
a_2 = [2*i for i in 1:6]
b_1 = 1:6
b_2 = 7:12
c_1 = 1:6
c_2 = [12, 11, 10, 9, 8, 7]

pair_1 = @constraint(roster, [k in 7:21, (a,b) in zip(a_1,a_2), s in WE],
            WeC_1[a,k,s] - WeC_2[b,k,s] == 0)
Xpair_1 = @constraint(roster, [(a,b) in zip(a_1,a_2)],
            WeC_1[a,6,2] - WeC_2[b,6,2] == 0)
pair_1a = @constraint(roster, [k in 7:21, (a,b) in zip(a_1,a_2), s in WE],
            WeC_1[b,k,s] - WeC_2[a,k,s] == 0)
Xpair_1a = @constraint(roster, [(a,b) in zip(a_1,a_2)],
            WeC_1[b,6,2] - WeC_2[a,6,2] == 0)
pair_2 = @constraint(roster, [k in 22:37, (a,b) in zip(b_1,b_2), s in WE],
            WeC_1[a,k,s] - WeC_2[b,k,s] == 0)
pair_2a = @constraint(roster, [k in 22:37, (a,b) in zip(b_1,b_2), s in WE],
            WeC_1[b,k,s] - WeC_2[a,k,s] == 0)
pair_3 = @constraint(roster, [k in 38:52, (a,b) in zip(c_1,c_2), s in WE],
            WeC_1[a,k,s] - WeC_2[b,k,s] == 0)
pair_3a = @constraint(roster, [k in 38:52, (a,b) in zip(c_1,c_2), s in WE],
            WeC_1[b,k,s] - WeC_2[a,k,s] == 0)


TIL_constraint = @constraint(roster, [i in Intern, k in 1:51, s in WE],
        WeC_1[i,k,s] + WeC_2[i,k,s] + WeD[i,k,s] - TIL[i,k+1,s] == 0)

@variable(roster, t[Intern, Week], Bin)

No_TIL_1 = @constraint(roster, [i in Intern, k in Week, d in WE, j in [12,13,20]],
            TIL[i,k,d] - t[i,k] <= 0)
No_TIL_2 = @constraint(roster, [i in Intern, k in Week, j in [12,13,20]],
             x[i,k,j] + t[i,k]  <= 1)

ADOs_total = @constraint(roster, [i in Intern],
                sum(ADO[i,k,d] for k in 5:52, d in Day) == 11)
ADOs_none = @constraint(roster, sum(ADO[i,k,d] for i in Intern, k in 1:4, d in Day) == 0)

ADO_none_oct = @constraint(roster, sum(ADO[i,k,d] for i in Intern, k in 40:43, d in Day) == 0)

@variable(roster, η[Intern, Week], Bin)

TIL_ADOs = @constraint(roster, [i in Intern, k in Week, s in WE, d in Day],
            TIL[i,k,s] + ADO[i,k,d] <= 1 ) # + η[i,k]

ADOs_AL = @constraint(roster, [i in Intern, k in Week, d in Day],
            ADO[i,k,d] + x[i,k,20] <= 1)

SEM_ADOs = @constraint(roster, [i in Intern, k in Week, s in WE, d in Day],
            SEM[i,k,s] + ADO[i,k,d]+ x[i,k,20] <= 1)


SpacedOutADOS_1 = @constraint(roster, [i in Intern, β in 0:7],
                sum(ADO[i,5 + α + 4*β, d] for d in Day, α in 0:6) >= 1)
SpacedOutADOS_2 = @constraint(roster, [i in Intern, β in 10:11],
                sum(ADO[i,3 + α + 4*β, d] for d in Day, α in 0:4) >= 1)


FriADO = @constraint(roster, [i in Intern], sum(ADO[i, k, 5] for k in Week) >= 5)
WedADO = @constraint(roster, [i in Intern], sum(ADO[i, k, 3] for k in Week) >= 5)

# for i in 0:7
#     for j in 0:6
#         println(5 + 4*i + j)
#     end
# end
#
# for i in 10:11
#     for j in 0:4
#         println(3 + 4*i + j)
#     end
# end

# WedFriADO = @constraint(roster, sum(ADO[i,k,d] for i in Intern, k in Week, d in [4]) ==0)


Late_Shift = @constraint(roster, [k in 5:52], sum(LATE[i, k] for i in Intern) == 1)

Even_Lates = @constraint(roster, [i in Intern], sum(LATE[i,k] for k in Week) ==4)

No_Early_Late = @constraint(roster, sum(LATE[i,k] for i in Intern, k in 1:4) == 0)

@variable(roster, θ[Intern, Week], Bin)

TIL_LATEs = @constraint(roster, [i in Intern, k in Week],
            sum(TIL[i,k,d] for d in WE) + LATE[i,k] <= 1 + θ[i,k])

@variable(roster, ω[Intern, Week], Bin)

ADO_LATEs = @constraint(roster, [i in Intern, k in Week],
            sum(ADO[i,k,d] for d in Day) + LATE[i,k] <= 1 + ω[i,k])

lateCons = @expression(roster, sum(θ[i,k] + ω[i,k] for i in Intern, k in Week)) # + 100*η[i,k]

# NLR = [3,5,6,7,8,9,10,12,13,15,16,17,18,19,20] # change for Sam
NLR = [ 2, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 19, 20, 21]


@variable(roster, n[Intern, Week], Bin)

LATE_at_Clay_1 = @constraint(roster, [i in Intern, k in Week],
                    LATE[i,k] - n[i,k] <= 0)
LATE_at_Clay_2 = @constraint(roster, [i in Intern, k in Week, j in NLR],
                    x[i,k,j] + n[i,k] <= 1)

Pub_Weeks = [4,11,15,16,17,24,39,44,52,52]
Pub_Days =  [3, 1, 5, 1, 1, 1, 5, 2, 1, 2]

PUB_ADOs = @constraint(roster, sum(ADO[i, k, d] for i in Intern, k in Pub_Weeks, d in Day) ==0)

Pub_Shifts_Clay_1 = @constraint(roster, [(k,d) in zip(Pub_Weeks,Pub_Days)],
                    sum(PubC_1[i,k,d] for i in Intern) == 1)
Pub_Shifts_Clay_2 = @constraint(roster, [(k,d) in zip(Pub_Weeks,Pub_Days)],
                    sum(PubC_2[i,k,d] for i in Intern) == 1)
Pub_Shifts_Dan = @constraint(roster, [(k,d) in zip(Pub_Weeks,Pub_Days)],
                    sum(PubD[i,k,d] for i in Intern) == 1)

Pubpair_1 = @constraint(roster, [k in 6:21, (a,b) in zip(a_1,a_2), s in Day],
            PubC_1[a,k,s] - PubC_2[b,k,s] == 0)
Pubpair_1a = @constraint(roster, [k in 6:21, (a,b) in zip(a_1,a_2), s in Day],
            PubC_1[b,k,s] - PubC_2[a,k,s] == 0)
Pubpair_2 = @constraint(roster, [k in 22:37, (a,b) in zip(b_1,b_2), s in Day],
            PubC_1[a,k,s] - PubC_2[b,k,s] == 0)
Pubpair_2a = @constraint(roster, [k in 22:37, (a,b) in zip(b_1,b_2), s in Day],
            PubC_1[b,k,s] - PubC_2[a,k,s] == 0)
Pubpair_3 = @constraint(roster, [k in 38:52, (a,b) in zip(c_1,c_2), s in Day],
            PubC_1[a,k,s] - PubC_2[b,k,s] == 0)
Pubpair_3a = @constraint(roster, [k in 38:52, (a,b) in zip(c_1,c_2), s in Day],
            PubC_1[b,k,s] - PubC_2[a,k,s] == 0)

PersonLimit = @constraint(roster, [i in Intern, (k,d) in zip(Pub_Weeks,Pub_Days)],
                PubC_1[i,k,d] + PubC_2[i,k,d] + PubD[i,k,d] <= 1)

# NoPubADOs = @constraint(roster,
#             sum(ADO[i,k,d] for i in Intern, (k,d) in zip(Pub_Weeks,Pub_Days)) == 0)

@variable(roster, p[Intern, Week], Bin)


NoPubDuringAL_1 = @constraint(roster,[i in Intern, (k,d) in zip(Pub_Weeks,Pub_Days)],
            x[i,k,20] - p[i,k] <= 0)

NoPubDuringAL_2 = @constraint(roster,[i in Intern, (k,d) in zip(Pub_Weeks,Pub_Days)],
            PubC_1[i,k,d] + PubC_2[i,k,d] + PubD[i,k,d] + p[i,k] <= 1)

# No_WE_after_leave = @constraint(roster, [i in Intern, k in 1:51, d in WE],
#             WeC_1[i,k,d] + WeC_2[i,k,d] + WeD[i,k,d] + y[i,k,20] <= 1)



MaxPubWork = @constraint(roster, [i in Intern],
                sum( (PubC_1[i,k,d] + PubC_2[i,k,d] + PubD[i,k,d]) for (k,d) in zip(Pub_Weeks,Pub_Days) ) <= 3)

Sem_Weeks = [7,7,22,22,29,29,39,39]
Sem_Days =  [1,2, 1, 2, 1, 2, 1, 2]

Seminars = @constraint(roster,
            sum(SEM[i,k,d] for i in Intern, (k,d) in zip(Sem_Weeks,Sem_Days)) == 96)

C = @expression(roster,
    sum( (PubC_1[i,k,d] + PubC_2[i,k,d] + PubD[i,k,d] + SEM[i,k,s] + ADO[i,k,d] + LATE[i,k] + TIL[i,k,s])
    for i in Intern, k in Week, d in Day, s in WE ))


# obj = @objective(roster, Min, z + C)
#
# optimize!(roster)

@variable(roster, ϕ[Intern, Week], Bin)

LateAndDisp = @constraint(roster, [i in Intern, k in 5:52], LATE[i,k] + x[i,k,14] - 2*ϕ[i,k] >= 0)

MaxLateDisp = @expression(roster, sum(ϕ[i,k] for i in Intern, k in 5:52))

# LateDisp = @expression(roster, sum((LATE[i,k]*x[i,k,14]) for i in Intern, k in 5:52)) #get rid of if possible
# technically this makes the model an NLP, but we'll try and get away with a quadratic program.
# at least its only in the obj function

# obj = @objective(roster, Min, z + C - LateDisp)
obj = @objective(roster, Min, z + C + lateCons - MaxLateDisp)

optimize!(roster)


#_________________________________________________________________________

wd = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
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

JuMP.value.(WeC_1[:,1,1])
JuMP.value.(WeC_2[:,1,1])

Pub_container = []
ABC = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

for (i,j) in zip(Pub_Weeks, Pub_Days)
    push!(Pub_container, sum(ABC .* Vector(JuMP.value.(PubC_1[:,i,j]))))
    push!(Pub_container, sum(ABC .* Vector(JuMP.value.(PubC_2[:,i,j]))))
    push!(Pub_container, sum(ABC .* Vector(JuMP.value.(PubD[:,i,j]))))
end

Pub_container = reshape(Pub_container, 3, 10)

 Weekend = [reshape(Weekend_roster[1:18],3,6) reshape(Pub_container[1:3],3,1) (
    reshape(Weekend_roster[19:60],3,14) ) reshape(Pub_container[4:6],3,1) (
    reshape(Weekend_roster[61:84],3,8) ) reshape(Pub_container[7:9],3,1) (
    reshape(Weekend_roster[85:90],3,2) ) reshape(Pub_container[10:12],3,1) (
    reshape(Weekend_roster[91:96],3,2) ) reshape(Pub_container[13:15],3,1) (
    reshape(Weekend_roster[97:138],3,14) ) reshape(Pub_container[16:18],3,1) (
    reshape(Weekend_roster[139:228],3,30) ) reshape(Pub_container[19:21],3,1) (
    reshape(Weekend_roster[229:258],3,10) ) reshape(Pub_container[22:24],3,1) (
    reshape(Weekend_roster[259:306],3,16) ) reshape(Pub_container[25:30],3,2) (
    reshape(Weekend_roster[307:312],3,2) )]

Weekend_roster = convert.(Int64, round.(Weekend))


XLSX.openxlsx("output/2022_roster.xlsx", mode="rw") do xf
    XLSX.addsheet!(xf, "Weekends")
    sheet = xf[2]
    sheet["B4:DK6"] = Weekend_roster
end

#_________________________________________________________________________
ados_out = string.(convert.(Int64,
    round.(sum((d*Matrix(JuMP.value.(ADO[:,:,d]))) for d in 1:5))))

weekdays = [ "Mon", "Tues", "Wed", "Thur", "Fri" ]
for d in 1:5
    replace!(ados_out, Nums[d] => weekdays[d])
end
XLSX.openxlsx("output/2022_roster.xlsx", mode="rw") do xf
    XLSX.addsheet!(xf, "ADOs")
    sheet = xf[3]
    sheet["B1:BA1"] = list
    sheet["B4:BA15"] = ados_out
end
#_________________________________________________________________________
til_out = string.(convert.(Int64,
    round.(sum((d*Matrix(JuMP.value.(TIL[:,:,d]))) for d in 1:2))))
for d in 1:2
    replace!(til_out, Nums[d] => weekdays[d])
end
XLSX.openxlsx("output/2022_roster.xlsx", mode="rw") do xf
    XLSX.addsheet!(xf, "TIL")
    sheet = xf[4]
    sheet["B1:BA1"] = list
    sheet["B4:BA15"] = til_out
end
#_________________________________________________________________________
late = (out).*Matrix(JuMP.value.(LATE[:,:]))
late = string.(convert.(Int64, round.(late)))
for j in 1:21
    replace!(late, Nums[j] => Names[j])
end
XLSX.openxlsx("output/2022_roster.xlsx", mode="rw") do xf
    XLSX.addsheet!(xf, "Late_Shift")
    sheet = xf[5]
    sheet["B1:BA1"] = list
    sheet["B4:BA15"] = late
end
#_________________________________________________________________________


# finding a replicable way to create individual rosters

function jump_to_int(intern)
    convert.(Int64, round.(Matrix(JuMP.value.(x[intern,:,:]))'))
end

function convert_rots_to_vector(x)
    rot_nums = [i for i in Rotation]'
    rot_nums * x
end

function make_5_day_week(x)
    repeat(x, 5,1)
end

function replace_rotations(x)
    x = string.(x)
    Names = ["IP", "MCH", "AP", "MIC", "CPDan-G", "CPDan-V", "CPDan-MH",
        "CPCas-G", "CPMoor", "CPKing", "CPClay", "HOMR/AAC", "QUM", "Disp-Clay", "Disp-Dan",
        "Disp-King", "Disp-Moor", "Disp-Cas", "CPCas-ED", "AL", "CPClay-G"]
    Nums = string.(collect(1:21))
    for j in 1:21
        replace!(x, Nums[j] => Names[j])
    end
    return x
end

function weekend_out(intern)
    function jump_custom(X)
        convert.(Int64, round.(Matrix(JuMP.value.(X))'))
    end
    w1 = jump_custom(WeC_1[intern,:,:])
    w2 = 2*jump_custom(WeC_2[intern,:,:])
    w3 = 3*jump_custom(WeD[intern,:,:])
    w1+w2+w3
end

function f(x)
    x > 0
end

function publics(rost, intern)
    pub1 = findall(f,Matrix(JuMP.value.(PubC_1[intern,:,:]))')
    pub2 = findall(f,Matrix(JuMP.value.(PubC_2[intern,:,:]))')
    pub3 = findall(f,Matrix(JuMP.value.(PubD[intern,:,:]))')
    for i in pub1
        rost[i] = 1
    end
    for i in pub2
        rost[i] = 2
    end
    for i in pub3
        rost[i] = 3
    end
    rost
end

function find_ados(rost, intern)
    adooo = findall(f,Matrix(JuMP.value.(ADO[intern,:,:]))')
    for i in adooo
        rost[i] = 4
    end
    rost
end

function find_til(rost, intern)
    til = findall(f,Matrix(JuMP.value.(TIL[intern,:,:]))')
    for i in til
        rost[i] = 5
    end
    rost
end

function lateShifts(rost, intern)
    l = convert.(Int64, round.(6*Vector(JuMP.value.(LATE[intern,:]))'))
    [l ; rost]
end

function replace_rest(x)
    x = string.(x)
    rot_num = ["1" "2" "3" "4" "5" "6"]
    rot_name = ["W/E_Clay_1" "W/E_Clay_2" "W/E_Dan" "ADO" "TIL" "LATE SHIFT"]
    for i in 1:length(rot_num)
        replace!(x, rot_num[i] => rot_name[i])
    end
    x
end


function indiv_roster(intern, filename, sheetname)
    rrr = jump_to_int(intern)
    v1 = convert_rots_to_vector(rrr)
    v1 = make_5_day_week(v1)
    str_ouput_weekedays = replace_rotations(v1)
    W = weekend_out(intern)
    combined_roster = [str_ouput_weekedays; W]
    rost_with_ados = find_ados(combined_roster, intern)
    rost_with_til = find_til(rost_with_ados, intern)
    for i in 1:length(Pub_Days)
        combined_roster[Pub_Days[i], Pub_Weeks[i]] = 99
    end
    for i in 1:length(Sem_Days)
        combined_roster[Sem_Days[i], Sem_Weeks[i]] = 101
    end
    rost_with_pubs = publics(rost_with_til, intern)
    final_rost = lateShifts(rost_with_til, intern)
    final_rost_str = replace_rest(final_rost)

    XLSX.openxlsx(filename, mode="rw") do xf
        XLSX.addsheet!(xf, sheetname)
        sheet = xf[intern + 5]
        sheet["B1:BA1"] = list
        sheet["B4:BA11"] = final_rost_str
    end
end

for i in 1:12
    indiv_roster(i, "output/2022_roster.xlsx", "Intern $(i) Roster")
end
