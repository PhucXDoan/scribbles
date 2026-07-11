if ($args[0] -eq "release") {

    clear && odin build . -vet-shadowing -o:none -max-error-count:1 -subsystem:windows -define:VERSION="$(git describe --tags)" && .\scribbles.exe

} elseif ($args[0] -eq "debug") {

    clear && odin build . -vet-shadowing -o:none -max-error-count:1 -debug -define:VERSION="$(git describe --tags)" && .\scribbles.exe
}
