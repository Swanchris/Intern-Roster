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

week_g = @constraint(roster, [(m,d) in zip(1:4, [17:22, 34:40, 47:52, 47:52])],
                sum(L[m,k] for k in d) >=1)
week_l = @constraint(roster, [(m,d) in zip(1:4, [17:22, 34:40, 47:52, 47:52])],
                sum(L[m,k] for k in d) <=3)

DontLetLDoubleUp = @constraint(roster, [k in Week], sum(L[m,k] for m in 1:4) <=1)

First_week_allocation = @constraint(roster, [k in 17:22], sum(x[i,k,20] for i in Intern)
                        - 4*L[1,k] >= 0)


Second_week_allocation = @constraint(roster, [k in 34:40], sum(x[i,k,20] for i in Intern)
                        - 4*L[2,k] >= 0)

Third_week_allocation = @constraint(roster, [ k in 47:52, m in 3:4],
                        sum(x[i,k,20] for i in Intern) - 4*L[m,k] ==0)

Third_week_dvar = @constraint(roster, [i in Intern], sum(y[i,k,20] for k in 47:51) -1 ==0 )

Third_week_block = @constraint(roster, [i in Intern, k in 47:51], 2 - sum(x[i, k + alpha, 20] for alpha in 0:1)
                    - 2*(1 - y[i, k, 20]) <= 0)


# Physical Constraint _________________________________________________________________________

physical = @constraint(roster, [i in Intern, k in Week], sum(x[i,k,j] for j in Rotation) -1 ==0)


z = @expression(roster, sum(x[i,k,j] for i in Intern, j in Rotation, k in Week))
obj_z = @objective(roster, Max, z)

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
XLSX.openxlsx("test01_0507_13.44.xlsx", mode="w") do xf
    sheet = xf[1]
    sheet["B1:BA1"] = list
    sheet["B4:BA15"] = df
end
