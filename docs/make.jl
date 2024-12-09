push!(LOAD_PATH,"../src/")
using Documenter, Buffers, Changelog

DocMeta.setdocmeta!(Buffers, :DocTestSetup, :(using Buffers); recursive=true)

# Generate a Documenter-friendly changelog from CHANGELOG.md
Changelog.generate(
    Changelog.Documenter(),
    joinpath(@__DIR__, "..", "CHANGELOG.md"),
    joinpath(@__DIR__, "src", "release-notes.md");
    repo = "fkfest/Buffers.jl",
)

makedocs(
  modules = [Buffers],
  format = Documenter.HTML(
    # Use clean URLs, unless built as a "local" build
    prettyurls = !("local" in ARGS),
    #assets = ["assets/favicon.ico"],
  ),
  sitename="Buffers.jl documentation",
  pages = [
    "Home" => "index.md",
    "Manual" => [
      "Guide" => "guide.md",
      "Preallocation" => "prealloc.md",
      "Tensor contractions" => "tensor_contractions.md",
      ],
    "Internals" => [
      "buffers.md"
    ],
    "release-notes.md", 
  ],
  checkdocs=:exports)

deploydocs(
    repo = "github.com/fkfest/Buffers.git",
)
