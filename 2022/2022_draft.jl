using JuMP, Gurobi
import XLSX
roster = direct_model(Gurobi.Optimizer())

Intern = 1:12
Week = 1:52
Rotation = 1:20

@variables(roster, begin
    x[Intern, Week, Rotation], Bin
    y[Intern, Week, Rotation], Bin
    L[1:7, Week], Bin
end
)

# Leave _________________________________________________________________________

Four_weeks = @constraint(roster, [i in Intern],
            sum(x[i,k,20] for k in Week) - 4 ==0)

First_week = @constraint(roster, sum(L[1,k] for k in 17:22) -1 ==0)

First_week_allocation = @constraint(roster, [k in 17:22], sum(x[i,k,20] for i in Intern)
                        - 12*L[1,k] == 0)

Second_week = @constraint(roster, [m in 2:3], sum(L[m, k] for k in 34:40) -1 ==0)

Second_week_allocation = @constraint(roster, [k in 34:40, m in 2:3], sum(x[i,k,20] for i in Intern)
                            - 6*L[m,k] == 0)

Third_week = @constraint(roster, [m in 4:7], sum(L[m,k] for k in 49:52) -1 == 0)

Third_week_allocation = @constraint(roster, [ k in 49:52, m in 4:7],
                        sum(x[i,k,20] for i in Intern) - 6*L[m,k] ==0)

Third_week_dvar = @constraint(roster, [i in Intern], sum(y[i,k,20] for k in 49:51) -1 ==0 )

Third_week_block = @constraint(roster, [i in Intern, k in 49:51], 2 - sum(x[i, k + alpha, 20] for alpha in 0:1)
                    - 2*(1 - y[i, k, 20]) <= 0)


# Physical Constraint _________________________________________________________________________

physical = @constraint(roster, [i in Intern, k in Week], sum(x[i,k,j] for j in Rotation) -1 ==0)

z = @expression(roster, sum(x[i,k,j] for i in Intern, j in Rotation, k in Week))
obj_z = @objective(roster, Max, z)

optimize!(roster)

print(JuMP.value.(L))




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
XLSX.openxlsx("test01_0507_13.52.xlsx", mode="w") do xf
    sheet = xf[1]
    sheet["B1:BA1"] = list
    sheet["B4:BA15"] = df
end
