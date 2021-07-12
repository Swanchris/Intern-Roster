using JuMP
using Gurobi

roster = Model(with_optimizer(Gurobi.Optimizer))


Intern = 1:11 #i
Week = 1:54  #k
Rotation = 1:17 #j
Leave_week = 1:3
M = 1000

@variables(roster, begin
    x[Intern,Week, Rotation], Bin
    D[Week], Bin
    y[Intern,Week, Rotation], Bin
    L[Leave_week, Week], Bin
    s[Intern], Bin
end
)

#blocking out Rotation '17'

null_intern = [(1:6),(7:11),(1:6),(7:11)]
null_week = [(51:54), (1:4), (1:50),(5:54)]
null_rhs = [4,4,0,0]

@constraint(roster, null[(a,b,c) in zip(null_intern, null_week, null_rhs), i in a],
    sum(x[i,k,17] for k in b) == c)

#orientation

ori_rhs = [1,1,1,1,2,2]
ori_week = [(1:4),(5:8),(1:4),(5:8),(1:4),(5:8)]
ori_intern = [(1:6),(7:11),(1:6),(7:11),(1:6),(7:11)]
ori_rot = [5,5,9,9,10,10]

@constraint(roster, ori[(a,b,c,d) in zip(ori_intern, ori_rot, ori_week, ori_rhs), i in a],
    sum(x[i,k,b] for k in c) == d)

#physical constraint

@constraint(roster, phys[i in Intern, k in Week], sum(x[i,k,j] for j in Rotation) == 1)

#completion requisites
# j=12 (QUM) needs at least 1 week before June
# clinical competency not included

rot_length = [8,4,3,4,3,3,3,3,5,5,4,2,1]

@constraint(roster, complete[(b,d) in zip(Rotation, rot_length), i in Intern],
    sum(x[i,k,b] for k in Week) == d)

#Rotation capacity
# j=5 (MCH) will need  RHS = 1 after k >=5
# gen med pairing not included

cap_rhs = [2,1,1,1,2,1,1,1,2,3,5,1,1]

@constraint(roster, cap[(b,d) in zip(Rotation, cap_rhs), k in Week],
    sum(x[i,k,b] for i in Intern) <= d)

mch_cap = @constraint(roster, [k in 9:54], sum(x[i,k,Rotation[5]] for i in Intern) <= 1)

# duration
# not including constraint on MIC (j = 4)

dur_rot = [1,2,3,4,5,6,7,8,9,11]
durs = [8,4,3,2,2,3,3,3,4,4]

@constraint(roster, duration_dvar[(b,d) in zip(dur_rot, durs), i in Intern],
    sum(y[i,k,b] for k in 1:(54 - (d-1) ) ) == 1)
@constraint(roster, durations[(b,d) in zip(dur_rot, durs), i in Intern, k in 1:(54 - (d-1) )],
    d - sum(x[i, k + alpha, b] for alpha in 0:(d-1) ) <= M*(1-y[i,k,b]))

#leave

week1_dvar = @constraint(roster, sum(L[1, k] for k in 17:22) == 1)
@constraint(roster, week1[k in 17:22], sum(x[i,k,14] for i in Intern) == 11*L[1,k])

@constraint(roster, week2_3_dvar[l in 2:3], sum(L[l, k] for k in 35:41) == 1)
@constraint(roster, week2_3[(l, j, rhs) in zip(2:3, 15:16, [6,5]), k in 35:41],
    sum(x[i,k,j] for i in Intern) == rhs*L[l, k] )

# leave max:

# @constraint(roster, max_leave[i in Intern], sum(x[i,j,k] for j in 14:16, k in Week) ==2)


# ignoring public holiday constraints

@expression(roster, z, sum(x[i,k,j] for i in Intern, j in Rotation, k in Week))

@objective(roster, Min, z)

optimize!(roster)

println(JuMP.value.(x))

g = sum((i*Matrix(JuMP.value.(x[:,:,i]))) for i in 1:17)

println(g)


# h = convert(Array{Int64}, round.(g))

println(h)

import XLSX

data = [10.0 9.0 10.0 5.0 4.0 3.0 3.0 3.0 4.0 4.0 4.0 10.0 2.0 2.0 2.0 2.0 13.0 8.0 8.0 8.0 14.0 5.0 5.0 10.0 7.0 7.0 7.0 6.0 6.0 6.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 16.0 11.0 11.0 11.0 11.0 9.0 9.0 9.0 9.0 10.0 12.0 12.0 17.0 17.0 17.0 17.0; 10.0 9.0 10.0 5.0 2.0 2.0 2.0 2.0 9.0 9.0 9.0 9.0 4.0 4.0 12.0 10.0 12.0 3.0 3.0 3.0 14.0 4.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 10.0 4.0 5.0 5.0 15.0 11.0 11.0 11.0 11.0 13.0 7.0 7.0 7.0 10.0 6.0 6.0 6.0 8.0 8.0 8.0 17.0 17.0 17.0 17.0; 10.0 5.0 10.0 9.0 11.0 11.0 11.0 11.0 6.0 6.0 6.0 5.0 5.0 8.0 8.0 8.0 9.0 9.0 9.0 9.0 14.0 2.0 2.0 2.0 2.0 4.0 4.0 7.0 7.0 7.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 16.0 4.0 10.0 13.0 12.0 12.0 4.0 10.0 10.0 3.0 3.0 3.0 17.0 17.0 17.0 17.0; 5.0 10.0 9.0 10.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 7.0 7.0 7.0 13.0 2.0 2.0 2.0 2.0 14.0 3.0 3.0 3.0 4.0 11.0 11.0 11.0 11.0 5.0 5.0 10.0 4.0 4.0 15.0 8.0 8.0 8.0 12.0 9.0 9.0 9.0 9.0 4.0 10.0 12.0 10.0 6.0 6.0 6.0 17.0 17.0 17.0 17.0; 9.0 10.0 5.0 10.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 6.0 6.0 6.0 7.0 7.0 7.0 4.0 4.0 14.0 10.0 13.0 4.0 8.0 8.0 8.0 11.0 11.0 11.0 11.0 12.0 10.0 3.0 3.0 3.0 4.0 10.0 16.0 12.0 5.0 5.0 9.0 9.0 9.0 9.0 2.0 2.0 2.0 2.0 17.0 17.0 17.0 17.0; 5.0 10.0 9.0 10.0 6.0 6.0 6.0 4.0 5.0 5.0 12.0 9.0 9.0 9.0 9.0 10.0 11.0 11.0 11.0 11.0 14.0 10.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 12.0 7.0 7.0 7.0 2.0 2.0 2.0 2.0 16.0 3.0 3.0 3.0 8.0 8.0 8.0 4.0 4.0 13.0 4.0 10.0 17.0 17.0 17.0 17.0; 17.0 17.0 17.0 17.0 10.0 5.0 9.0 10.0 11.0 11.0 11.0 11.0 10.0 3.0 3.0 3.0 9.0 9.0 9.0 9.0 14.0 12.0 4.0 5.0 5.0 12.0 2.0 2.0 2.0 2.0 13.0 10.0 8.0 8.0 8.0 6.0 6.0 6.0 16.0 10.0 4.0 4.0 4.0 7.0 7.0 7.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0; 17.0 17.0 17.0 17.0 9.0 10.0 10.0 5.0 7.0 7.0 7.0 12.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 14.0 11.0 11.0 11.0 11.0 10.0 3.0 3.0 3.0 10.0 2.0 2.0 2.0 2.0 15.0 10.0 12.0 4.0 8.0 8.0 8.0 6.0 6.0 6.0 13.0 5.0 5.0 9.0 9.0 9.0 9.0 4.0 4.0 4.0; 17.0 17.0 17.0 17.0 10.0 10.0 9.0 5.0 11.0 11.0 11.0 11.0 12.0 10.0 4.0 4.0 6.0 6.0 6.0 12.0 14.0 8.0 8.0 8.0 9.0 9.0 9.0 9.0 4.0 3.0 3.0 3.0 10.0 10.0 15.0 7.0 7.0 7.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 13.0 4.0 5.0 5.0 2.0 2.0 2.0 2.0; 17.0 17.0 17.0 17.0 5.0 9.0 10.0 10.0 8.0 8.0 8.0 4.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 14.0 11.0 11.0 11.0 11.0 9.0 9.0 9.0 9.0 4.0 4.0 6.0 6.0 6.0 15.0 4.0 3.0 3.0 3.0 10.0 12.0 12.0 2.0 2.0 2.0 2.0 10.0 7.0 7.0 7.0 13.0 5.0 5.0 10.0; 17.0 17.0 17.0 17.0 9.0 5.0 10.0 10.0 2.0 2.0 2.0 2.0 11.0 11.0 11.0 11.0 4.0 12.0 5.0 5.0 14.0 7.0 7.0 7.0 6.0 6.0 6.0 4.0 10.0 8.0 8.0 8.0 10.0 12.0 15.0 9.0 9.0 9.0 9.0 10.0 13.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 4.0 4.0 3.0 3.0 3.0]


Names = ["CPD-G", "CPD-V", "AP", "MIC", "MCH", "CPCa", "CPM", "CPK", "IP", "DISP", "CPC", "QUM", "H", "AL", "AL", "AL", "-"]

Nums = string.(collect(1:17))

df = string.(convert.(Int64, data))

for i in 1:17
    replace!(df, Nums[i] => Names[i])
end


XLSX.openxlsx("2020.xlsx", mode="w") do xf
    sheet = xf[1]
    sheet["B2:BC12"] = df
end
