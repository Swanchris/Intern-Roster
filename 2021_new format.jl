using JuMP
using Gurobi
import XLSX
roster = Model(Gurobi.Optimizer)


Intern = 1:11 #i
Week = 1:55  #k
Rotation = 1:23 #j
Leave_week = 1:3
M = 1000

@variables(roster, begin
    x[Intern,Week, Rotation], Bin
    y[Intern,Week, Rotation], Bin
    L[Leave_week, Week], Bin
    s[Intern], Bin
end
)

#blocking out Rotation '23'
@constraint(roster, [i in Intern], sum(x[i,k,23] for k in 1:2) == 2)

#physical constraint
@constraint(roster, phys[i in Intern, k in Week],
    sum(x[i,k,j] for j in Rotation) == 1)

#completion requisites
complete_soft = @constraint(roster,
    [(b,d) in zip([1,2,5,6,8,9,10,11,14,15,16,17,18,19], [5,2,7,4,3,3,3,3,2,2,1,1,1,1]), i in Intern],
    sum(x[i,k,b] for k in Week) >= d)
complete_hard = @constraint(roster,
    [(b,d) in zip([3,4,7,12,13], [3,4,1,1,2]), i in Intern],
    sum(x[i,k,b] for k in Week) == d)
block_1_rots = [14:15, 16:19, 13, 12, 1]
block_1_rhs = [2,2,1,1,1]
block_1 = @constraint(roster, [(b,d) in zip(block_1_rots, block_1_rhs), i in Intern],
    sum(x[i,k,j] for k in 3:22, j in b) >= d)

#qum_week_2 - second week before october
@constraint(roster, sum(x[i,k,13] for k in 1:39) == 2)

real_rotations = @constraint(roster, [(b,d) in zip([20:22, 23], [2,2]), i in Intern],
    sum(x[i,k,j] for k in Week, j in b) == d)


#Rotation capacity
cap_rhs = [2,1,1,1,2,1,1,1,1,1,4,1,1,2,2,1,1,1,1]
cap = @constraint(roster, [(b,d) in zip(Rotation, cap_rhs), k in Week],
    sum(x[i,k,b] for i in Intern) <= d)

# duration

# curently all y values that a real are appearing in k = 55 - need to fix!

dur_rot =   [1,2,3,5,6,8,9,10,11,14,15]
durs =      [4,2,3,7,4,3,3,3,4,2,2]
duration_dvar = @constraint(roster, [(b,d) in zip(dur_rot, durs), i in Intern],
    sum(y[i,k,b] for k in 1:(55 - (d-1) ) ) == 1)
durations = @constraint(roster, [(b,d) in zip(dur_rot, durs), i in Intern, k in 1:(55 - (d-1) )],
    d - sum(x[i, k + alpha, b] for alpha in 0:(d-1) ) <= M*(1-y[i,k,b]))
# mental_health_1 = @constraint(roster, [i in Intern, k in 2:48], x[i,k-1,7] - y[i,k, 5] == D[i,k])
# mental_health_2 = @constraint(roster, [i in Intern, k in 2:48], x[i,k+7,7] - y[i,k, 5] == (1 - D[i,k]))

mental_health = @constraint(roster, [i in Intern, k in 2:48], y[i,k, 5] - x[i,k-1,7] - x[i, k+7, 7] <= 0 )



#MIC
MIC_1_dvar = @constraint(roster, [i in Intern], sum(y[i,k,4] for k in 1:26 ) == 1)
MIC_2_dvar = @constraint(roster, [i in Intern], sum(y[i,k,4] for k in 26:54 ) == 1)
MIC = @constraint(roster, [ i in Intern, k in 1:26],
    2 - sum(x[i, k + alpha, 4] for alpha in 0:1 ) <= M*(1-y[i,k,4]))
MIC = @constraint(roster, [ i in Intern, k in 26:54],
    2 - sum(x[i, k + alpha, 4] for alpha in 0:1 ) <= M*(1-y[i,k,4]))

# Clinical Competency
clin_comp = @constraint(roster, [i in Intern], sum(x[i,k,j] for k in 1:16, j in [2,5,6,7,8,9,10,11]) >= 3)

#leave
week1_dvar = @constraint(roster, sum(L[1, k] for k in 17:22) == 1)
@constraint(roster, week1[k in 17:22], sum(x[i,k,20] for i in Intern) == 11*L[1,k])
@constraint(roster, week2_3_dvar[l in 2:3], sum(L[l, k] for k in 35:41) == 1)
@constraint(roster, week2_3[(l, j, rhs) in zip(2:3, 21:22, [6,5]), k in 35:41],
    sum(x[i,k,j] for i in Intern) == rhs*L[l, k] )
@constraint(roster, max_leave[i in Intern], sum(x[i,k,j] for j in 20:22, k in Week) ==2)

#  public holiday constraints
no_pubs = @constraint(roster,
    [i in Intern, k in [4,7,10,13,14,22,24,29,39,44,52], j in [13]],
    x[i,k,j] == 0 )

@expression(roster, z, sum(x[i,k,j] for i in Intern, j in Rotation, k in Week))

@objective(roster, Max, z)

optimize!(roster)

# println(JuMP.value.(x))



g = sum((i*Matrix(JuMP.value.(x[:,:,i]))) for i in 1:23)
Names = ["IP", "MCH", "AP", "MIC", "CPD-G", "CPD-V", "CPD-MH",
    "CPCa", "CPM", "CPK", "CPC", "H", "QUM", "Disp-Clay", "Disp-Dan",
    "Disp-MCH", "Disp-MB", "Disp-Cas", "Disp-King", "AL", "AL", "AL", "Orientation"]
Nums = string.(collect(1:23))
df = string.(convert.(Int64, g))
for i in 1:23
    replace!(df, Nums[i] => Names[i])
end
list = [i for i in 1:55]
XLSX.openxlsx("2021_draft.xlsx", mode="rw") do xf
    sheet = xf[1]
    sheet["B3:BD13"] = df
end
