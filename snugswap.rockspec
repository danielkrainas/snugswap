package = "snugswap"
version = "1.0.0-beta"
source = {
   url = "git+ssh://git@github.com/danielkrainas/snugswap.git"
}
description = {
   summary = "SnugSwap",
   detailed = "SnugSwap is a helper library for FFXI Windower GearSwap that lets you describe your gear setups in a more declarative and readable way.",
   homepage = "https://github.com/danielkrainas/snugswap",
   license = "https://creativecommons.org/publicdomain/zero/1.0/"
}
dependencies = {
   queries = {}
}
build_dependencies = {
   queries = {}
}
build = {
   type = "builtin",
   modules = {
      snugswap = "snugswap.lua"
   },
   copy_directories = {
      "docs"
   }
}
test_dependencies = {
   queries = {}
}
