using Pkg

pkg"update"

pkgs = getfield.(filter(p -> p.is_direct_dep, collect(values(Pkg.dependencies()))), :name)

Threads.@threads for p in pkgs
  try
    run(`$(Base.julia_cmd()) --project -e "import $p"`)
  catch e
    println("Ignoring error $e when importing package $p")
  end
end
