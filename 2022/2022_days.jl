using SparseArrays, DataFrames, CSV, JuMP, Gurobi
import XLSX
rotation_matrix = convert.(Int64, round.(convert(Matrix, CSV.read("2022/2022_V1_raw.csv"))))

daily = direct_model(Gurobi.Optimizer())

Intern = 1:12 # i
Rotation = 1:20 # j
Job = 1:7 # f
Week = 1:52 # k
Day = 1:7 # l



@variable(daily, z[Intern, Rotation, Job, Week, Day], Bin)

for a in 1:12
    @constraint(daily, [l in 1:5, (k,j) in zip(Week,rotation_matrix[a,:])],
                    z[a,j,1,k,l] ==1)
end


@objective(daily, Min, sum(z[i,j,f,k,l] for i in Intern, j in Rotation, f in Job, k in Week, l in Day))

optimize!(daily)

println(JuMP.value.(z[1,:,1,:,1]))
