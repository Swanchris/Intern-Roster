using JuMP
using Gurobi
import XLSX
roster = Model(Gurobi.Optimizer)

Intern = 1:11 #i
Week = 1:52  #k
Rotation = 1:24 #j
Leave_week = 1:3
Dec_leave = 1:2
M = 1000
clins = 7:52
non_clins = 5:52
early = 5:28
gen = [5,8]

@variables(roster, begin
    x[Intern,Week, Rotation], Bin
    y[Intern,Week, Rotation], Bin
    L[Leave_week, Week], Bin
    D[Dec_leave, Intern], Bin
    s[Intern, Week], Bin
    g[Intern, gen], Bin
end
)

#Orientation
# IP_1 = @constraint(roster, [i in Intern], sum(x[i,k,1] for k in 1:6) >= 1)
# # IP_2 = @constraint(roster, sum(x[i,k,1] for i in Intern, k in 1:4) == 8)
# IP_3_1 = @constraint(roster, [i in Intern], sum(s[i,k] for k in 1:4) <= 1)
# IP_3_11 = @constraint(roster, sum(s[i,k] for i in Intern, k in 1:4) == 8)
# IP_3_2 = @constraint(roster, [i in Intern, k in 1:4], x[i,k,1] == s[i,k])
IP_lazy = @constraint(roster, [(i,k) in zip(Intern, [1 1 2 2 3 3 4 4 5 5 6])], x[i,k,1] ==1)
orien = @constraint(roster, [i in Intern], sum(x[i,k,j] for k in 1:4, j in [1,14,15,16,17,18,19] ) == 4)

#MIC
MIC_1_dvar = @constraint(roster, [i in Intern], sum(y[i,k,4] for k in 5:27 ) == 1)
MIC_2_dvar = @constraint(roster, [i in Intern], sum(y[i,k,4] for k in 29:51 ) == 1)
MIC = @constraint(roster, [ i in Intern, k in 5:27],
    2 - sum(x[i, k + alpha, 4] for alpha in 0:1 ) <= M*(1-y[i,k,4]))
MIC = @constraint(roster, [ i in Intern, k in 29:51],
    2 - sum(x[i, k + alpha, 4] for alpha in 0:1 ) <= M*(1-y[i,k,4]))

# Clinical Competency
# clin_comp = @constraint(roster, [i in Intern], sum(x[i,k,j] for k in 1:16, j in [2,5,6,7,8,9,10,23]) >= 3)

#gen_med
g_vars = @constraint(roster, [i in Intern], sum(g[i,m] for m in gen) ==1)
gen_duration_dvar = @constraint(roster, [(b,d) in zip(gen,[6,7]), i in Intern],
                sum(y[i,k,b] for k in 1:(52 - (d-1) ) ) == g[i,b])
gen_durations = @constraint(roster, [(b,d) in zip(gen,[6,7]),
                i in Intern, k in 1:(52 - (d-1) )],
                d - sum(x[i, k + alpha, b] for alpha in 0:(d-1) ) <= M*(1-y[i,k,b]))
ed_with_gen = @constraint(roster, [i in Intern, k in 2:50], y[i,k,23] - x[i,k-1,8] - x[i,k+2,8] <= (1-g[i,5]))

#qum
qum_1 = @constraint(roster, [i in Intern], sum(x[i,k,13] for k in early) >= 1)
qum_2 = @constraint(roster, [i in Intern], sum(x[i,k,13] for k in 1:39) == 2)

#dispensary
disp  = @constraint(roster, [i in Intern], sum(x[i,k,j] for k in Week, j in 14:19) >= 5)
disp1 = @constraint(roster, [i in Intern], sum(x[i,k,j] for k in 29:40, j in 14:19) >= 1)
disp2 = @constraint(roster, [i in Intern], sum(x[i,k,j] for k in 41:52, j in 14:19) >= 1)

#Rotation capacity
rots    = [1,2,3,4,5,6,7,8,9,10,12,13,14,15,16,17,18,19,23]
cap_rhs = [2,1,1,1,1,1,1,1,1, 1, 1, 1, 2, 2, 1, 1, 2, 1, 1]
cap = @constraint(roster, [(b,d) in zip(rots, cap_rhs), k in 1:52],
    sum(x[i,k,b] for i in Intern) <= d)

#leave
# 2 weeks leave
@constraint(roster, [i in Intern],
                    sum(x[i,k,j] for k in Week, j in 20:22) == 2)
week1_dvar = @constraint(roster, sum(L[1, k] for k in 17:22) == 1)
@constraint(roster, week1[k in 17:22], sum(x[i,k,20] for i in Intern) == 11*L[1,k])
@constraint(roster, week2_3_dvar[l in 2:3], sum(L[l, k] for k in 35:41) == 1)
@constraint(roster, week2_3[(l, j, rhs) in zip(2:3, 21:22, [6,5]), k in 35:41],
    sum(x[i,k,j] for i in Intern) == rhs*L[l, k] )
@constraint(roster, max_leave[i in Intern], sum(x[i,k,j] for j in 20:22, k in Week) ==2)
## - Dec_leave
@constraint(roster,[i in Intern], sum(D[l,i] for l in 1:2) == 1)
@constraint(roster, [(l,d) in zip(1:2,[6,5])], sum(D[l,i] for i in Intern) == d)
@constraint(roster, [i in Intern, (l,b) in zip(1:2, [49:50, 51:52])],
    sum(x[i,k,24] for k in b) == 2*D[l,i])
@constraint(roster, [i in Intern], sum(x[i,k,24] for k in Week) == 2)

# duration
dur_rot =   [2,3,6,7,9,10,11,23]
durs =      [2,2,4,2,3, 3, 4, 2]
duration_dvar = @constraint(roster, [(b,d) in zip(dur_rot, durs), i in Intern],
                sum(y[i,k,b] for k in 1:(52 - (d-1) ) ) == 1)
durations = @constraint(roster, [(b,d) in zip(dur_rot, durs),
                i in Intern, k in 1:(52 - (d-1) )],
                d - sum(x[i, k + alpha, b] for alpha in 0:(d-1) ) <= M*(1-y[i,k,b]))

#physical constraint
@constraint(roster, phys[i in Intern, k in Week],
    sum(x[i,k,j] for j in Rotation) == 1)

# rotations_lengths
completion = @constraint(roster,
    [(j,c,d) in zip([1,2,3,4,6,7,9,10,11,12,23],
    [ 1:28,clins,non_clins, non_clins,clins,clins, clins, clins, 29:52, early, clins],
                    [3,2,3,4,4,2,3, 3, 4, 1, 2]), i in Intern],
                  sum(x[i,k,j] for k in c) == d)
IP_soft = @constraint(roster, [i in Intern], sum(x[i,k,1] for k in Week) >= 5)

#  public holiday constraints
no_pubs = @constraint(roster,
    [i in Intern, k in [4,7,10,13,14,22,24,29,39,44,52], j in [12,13]],
    x[i,k,j] == 0 )

z = @expression(roster, sum(x[i,k,j] for i in Intern, j in Rotation, k in Week))
obj_z = @objective(roster, Max, z)

optimize!(roster)

g = sum((i*Matrix(JuMP.value.(x[:,:,i]))) for i in 1:24)
Names = ["IP", "MCH", "AP", "MIC", "CPDan-G", "CPDan-V", "CPDan-MH",
    "CPCas-G", "CPMoor", "CPKing", "CPClay", "HOMR/AAC", "QUM", "Disp-Clay", "Disp-Dan",
    "Disp-MCH", "Disp-Moor", "Disp-Cas", "Disp-King", "AL", "AL", "AL", "CPCas-ED",  "AL"]
Nums = string.(collect(1:24))
df = string.(convert.(Int64, g))
for i in 1:24
    replace!(df, Nums[i] => Names[i])
end
list = convert(Array{Int64},transpose([i for i in 1:52]))
XLSX.openxlsx("2021_v1.xlsx", mode="w") do xf
    sheet = xf[1]
    sheet["B1:BA1"] = list
    sheet["B3:BA13"] = df
end
