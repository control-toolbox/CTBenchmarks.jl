"""
    This file contains the functions to display the results of the benchmarks
"""

function uniflag(flag)
    if flag == MOI.LOCALLY_SOLVED || flag == :first_order || flag == MOI.OPTIMAL || flag == 0 
        return "Solve Succeeded"
    elseif flag == MOI.ITERATION_LIMIT || flag == :max_iter
        return "Iterations Exceeded"
    elseif flag == MOI.LOCALLY_INFEASIBLE || flag == :infeasible
        return "Infeasible Problem"
    elseif flag == MOI.INVALID_MODEL || flag == "Invalid Model"
        return "Invalid Model"
    end
    return "UNI ? "*string(flag)
end

function display_Benchmark(Results, title, file_name, parameter_value)
    table = DataFrame(:Model => Symbol[], :nb_discr => Any[], :nvar => Any[], :ncon => Any[], :nb_iter => Any[], :total_time => Any[], :Ipopt_time => Any[], :obj_value => Any[], :flag => Any[])
    ex=[]
    for (k,v) in Results
        if length(v) > 0
            for i in v
                push!(table, [k; i.nb_discr[1]; i.nvar; i.ncon; i.nb_iter[1]; round(i.total_time[1],digits=2); round(i.Ipopt_time[1],digits=2); i.obj_value[1]; uniflag(i.flag[1])])
            end
        else
            push!(ex, [k])
        end
    end
    for i in ex
        push!(table, [i; NaN; NaN; NaN; NaN; NaN; NaN; NaN; "NaN"])
    end
    # Define the custom display
    header = ["Model","Discretization", "Variables","Constraints", "Iterations", "Total Time", "Ipopt Time" ,"Objective Value", "Flag"];
    hl_flags = LatexHighlighter( (table, i, j) -> ((j == 9) && (table[i, j] != "Solve Succeeded") && (table[i, j] != "NaN")),
                            ["color{red}"]
                        );
    original_stdout = stdout
    file = open("./outputs/$(file_name)", "w")
    try
        redirect_stdout(file)
        println("\\documentclass{standalone}")
        println("\\usepackage{color}")
        println("\\usepackage{booktabs}")
        println("\\begin{document}")
        println("\\begin{tabular}{c}")
        println("\\Large\\textbf{$title}\\\\")
        println("\\large\\textbf{$parameter_value}\\\\")
        pretty_table(
            table;
            (backend = Val(:latex)),
            header        = header,
            title = title,
            title_alignment = :c,
            alignment = :c,
            highlighters  = (hl_flags,)
        )
        println("\\end{tabular}")
        println("\\end{document}")
    finally
        redirect_stdout(original_stdout)
        close(file)
    end
end 


function display_Benchmark_model(Results, title, file_name,parameter_value)
    table = DataFrame(:solver => Symbol[], :Model => Symbol[], :nb_discr => Any[], :nvar => Any[], :ncon => Any[], :nb_iter => Any[], :total_time => Any[], :Ipopt_time => Any[], :obj_value => Any[], :flag => Any[])
        for (k,v) in Results
            for (m,s) in v
                for i in s
                    push!(table, [k; m; i.nb_discr[1]; i.nvar; i.ncon; i.nb_iter[1]; round(i.total_time[1],digits=2); round(i.Ipopt_time[1],digits=2); i.obj_value[1]; uniflag(i.flag[1])])
                end
            end
        end
        # Define the custom display
        header = ["Solver","Model","Discretization", "Variables","Constraints", "Iterations", "Total Time", "Ipopt Time" ,"Objective Value", "Flag"];
        hl_flags = LatexHighlighter( (table, i, j) -> ((j == 10) && (table[i, j] != "Solve Succeeded") && (table[i, j] != "NaN")),
                                ["color{red}"]
                            );
        original_stdout = stdout
        file = open("./outputs/$(file_name)", "w")
        try
            redirect_stdout(file)
            println("\\documentclass{standalone}")
            println("\\usepackage{color}")
            println("\\usepackage{booktabs}")
            println("\\begin{document}")
            println("\\begin{tabular}{c}")
            println("\\Large\\textbf{$title}\\\\")
            println("\\large\\textbf{$parameter_value}\\\\")
            pretty_table(
                table;
                (backend = Val(:latex)),
                header        = header,
                title = title,
                title_alignment = :c,
                alignment = :c,
                highlighters  = (hl_flags,)
            )
            println("\\end{tabular}")
            println("\\end{document}")
        finally
            redirect_stdout(original_stdout)
            close(file)
        end
    end 

function display_Benchmark_model_TTonly(Results, title, file_name,parameter_value)
    table = DataFrame(:Model => Symbol[], :nb_discr => Any[] ,:total_time_JuMP => Any[], :total_time_OC => Any[], :nb_iter_JuMP => Any[], :nb_iter_OC => Any[], :alloc_JuMP => Any[], :alloc_OC => Any[])
        for (k,s) in Results
            for i in s
                push!(table, [k; i.nb_discr ; round(i.TTJMP[1],digits=2); round(i.TTOC[1],digits=2); i.IterJuMP[1]; i.IterOC[1]; round(i.AllocJuMP[1]/1e6,digits=1); round(i.AllocOC[1]/1e6,digits=1)])
            end
        end
        # Define the custom display
        header = ["Model","Discretization", "Total Time JuMP", "Total Time OC", "Iterations JuMP", "Iterations OC", "Allocations JuMP(1e6)", "Allocations OC(1e6)"];
        original_stdout = stdout
        file = open("./outputs/$(file_name)", "w")
        try
            redirect_stdout(file)
            println("\\documentclass{standalone}")
            println("\\usepackage{color}")
            println("\\usepackage{booktabs}")
            println("\\begin{document}")
            println("\\begin{tabular}{c}")
            println("\\Large\\textbf{$title}\\\\")
            println("\\large\\textbf{$parameter_value}\\\\")
            pretty_table(
                table;
                (backend = Val(:latex)),
                header        = header,
                title = title,
                title_alignment = :c,
                alignment = :c,
            )
            println("\\end{tabular}")
            println("\\end{document}")
        finally
            redirect_stdout(original_stdout)
            close(file)
        end
    end 



function display_Callbacks(Results, title, file_name)
    table = DataFrame(:Model => Symbol[], :nb_discr => Any[], :nnzh => Any[], :nnzj => Any[], 
                        :t_obj => Any[], :t_grad => Any[], :t_cons => Any[], :t_jac => Any[], :t_hess => Any[])
    for (k,v) in Results
        for i in v
            push!(table, [k; i.nb_discr[1]; i.nnzh; i.nnzj; round(i.t_obj[1]*1e3,digits=2); round(i.t_grad[1]*1e3,digits=2); round(i.t_cons[1]*1e3,digits=2); round(i.t_jac[1]*1e3,digits=2); round(i.t_hess[1]*1e3,digits=2)])
        end
    end
    # Define the custom display
    header = ["Solver","Discretization", "nnz Hessian", "nnz Jacobian", "Time Obj(ms)", "Time Grad(ms)", "Time Cons(ms)", "Time Jac(ms)", "Time Hess(ms)"];
    original_stdout = stdout
    file = open("./outputs/$(file_name)", "w")
    try
        redirect_stdout(file)
        println("\\documentclass{standalone}")
        println("\\usepackage{color}")
        println("\\usepackage{booktabs}")
        println("\\begin{document}")
        println("\\begin{tabular}{c}")
        println("\\Large\\textbf{$title}\\\\")
        pretty_table(
            table;
            (backend = Val(:latex)),
            header        = header,
            title = title,
            title_alignment = :c,
            alignment = :c,
        )
        println("\\end{tabular}")
        println("\\end{document}")
    finally
        redirect_stdout(original_stdout)
        close(file)
    end
end


function display_Knitro(Results, title, file_name)
    table = DataFrame(:solver => Symbol[], :Model => Symbol[], :nb_discr => Any[], :nvar => Any[], :ncon => Any[], :nb_iter => Any[], :total_time => Any[], :knitro_time => Any[], :obj_value => Any[], :flag => Any[])
    for (k,v) in Results
        for i in v
            push!(table, [k; i.model[1]; i.nb_discr[1]; i.nvar; i.ncon; i.nb_iter[1]; round(i.total_time[1],digits=2); round(i.knitro_time[1],digits=2); i.obj_value[1]; uniflag(i.flag[1])])
        end
    end
    # Define the custom display
    header = ["Solver","Model","Discretization", "Variables","Constraints", "Iterations", "Total Time", "KNITRO Time" ,"Objective Value", "Flag"];
    hl_flags = LatexHighlighter( (table, i, j) -> ((j == 10) && (table[i, j] != "Solve Succeeded") && (table[i, j] != "NaN")),
                            ["color{red}"]
                        );
    original_stdout = stdout
    file = open("./outputs/$(file_name)", "w")
    try
        redirect_stdout(file)
        println("\\documentclass{standalone}")
        println("\\usepackage{color}")
        println("\\usepackage{booktabs}")
        println("\\begin{document}")
        println("\\begin{tabular}{c}")
        println("\\Large\\textbf{$title}\\\\")
        pretty_table(
            table;
            (backend = Val(:latex)),
            header        = header,
            title = title,
            title_alignment = :c,
            alignment = :c,
            highlighters  = (hl_flags,)
        )
        println("\\end{tabular}")
        println("\\end{document}")
    finally
        redirect_stdout(original_stdout)
        close(file)
    end
end 
