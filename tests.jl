using JuMP

model = JuMP.Model()

@variable(model, x[1:11, 1:17, 1:54], Bin)

I = [(1:6),(7:11),(1:6),(7:11)]
K = [(51:54), (1:4), (1:50),(5:54)]
RHS = [4,4,0,0]

@constraint(model, null[(a,b,c) in zip(I,K,RHS), i in a],
    sum(x[i,17,k] for k in b) == c)

println(null)

println(null[(1:6, 51:54, 4), 2])
