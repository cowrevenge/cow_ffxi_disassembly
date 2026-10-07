// TODO(trace): offline ZoneVis probe — loads zone .DAT MZB/MMB visual mesh without lobby/window.
// Usage: zonevis_probe.exe <42.DAT> [20.DAT ...]   (run from repo root)
#include "rom/zonevis.h"
#include "rom/texdat.h"

#include <cstdio>
#include <string>

int main(int argc, char** argv) {
    if (argc < 2) { std::fprintf(stderr, "usage: zonevis_probe.exe [--xyz <path>] <zone.DAT> [...]\n"); return 2; }
    const char* xyzPath = nullptr;
    int rc = 0;
    for (int i = 1; i < argc; ++i) {
        if (std::string(argv[i]) == "--xyz" && i + 1 < argc) { xyzPath = argv[++i]; continue; }
        const cow::rom::ZoneVis zv = cow::rom::ZoneVis::load(argv[i]);
        std::fprintf(stderr, "[probe] %s: loaded=%d pieces=%zu\n", argv[i], zv.loaded ? 1 : 0, zv.pieces.size());
        if (!zv.loaded) { rc = 1; continue; }
        // Texture binding check: exactly what glroom's zoneVisTextures does — byName(cat,name) per piece.
        const cow::rom::TexDat td = cow::rom::TexDat::load(argv[i]);
        size_t hits = 0, missLogged = 0;
        for (const auto& pc : zv.pieces) {
            if (td.byName(pc.texCat.c_str(), pc.texName.c_str())) ++hits;
            else if (missLogged < 12) {
                std::fprintf(stderr, "[probe]   MISS byName(cat='%s', name='%s')\n", pc.texCat.c_str(), pc.texName.c_str());
                ++missLogged;
            }
        }
        std::fprintf(stderr, "[probe]   texdat entries=%zu piece-texture hits=%zu/%zu\n", td.texs.size(), hits, zv.pieces.size());
        if (xyzPath) {
            std::FILE* fx = std::fopen(xyzPath, "w");
            if (fx) {
                size_t n = 0;
                for (const auto& pc : zv.pieces)
                    for (const auto& v : pc.verts) { std::fprintf(fx, "%.4f %.4f %.4f\n", v.x, v.y, v.z); ++n; }
                std::fclose(fx);
                std::fprintf(stderr, "[probe] xyz dump %s: %zu verts (client frame x,y-up,z)\n", xyzPath, n);
            }
        }
    }
    return rc;
}
