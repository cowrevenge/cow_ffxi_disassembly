// TODO(trace): offline ximesh probe — loads .ximesh through the real loader and prints census, world bounds,
// rotated-placement count, and placement rotation matrices near a requested anchor (transpose verification).
// Usage: ximesh_probe.exe <Port_Jeuno.ximesh> [ax ay az]   (run from repo root)
#include "rom/ximesh.h"

#include <cmath>
#include <cstdio>
#include <vector>

int main(int argc, char** argv) {
    if (argc < 2) { std::fprintf(stderr, "usage: ximesh_probe.exe <file.ximesh> [ax ay az]\n"); return 2; }
    const cow::rom::XiMesh m = cow::rom::XiMesh::load(argv[1]);
    if (!m.loaded) { std::fprintf(stderr, "[probe] %s: not loaded\n", argv[1]); return 1; }

    // index flag-bit census: LSB packs material bits into the DAT u16 indices; if .ximesh kept them, vertex
    // fetches would be wrong. Count any idx with high bits set and compare against per-block vertex counts.
    size_t hiBit = 0;
    for (const auto& b : m.blocks)
        for (uint16_t e : b.idx) if (e & 0x4000u) ++hiBit;
    std::fprintf(stderr, "[probe] index entries with high bit set: %zu (of %zu)\n", hiBit,
                 m.blocks.empty() ? 0 : m.blocks.size());

    size_t rotated = 0;
    for (const auto& pl : m.placements) {
        static const float ident[9] = {1,0,0, 0,1,0, 0,0,1};
        bool same = true;
        for (int k = 0; k < 9 && same; ++k) same = std::fabs(pl.rot[k] - ident[k]) < 1e-5f;
        if (!same) ++rotated;
    }
    std::fprintf(stderr, "[probe] %s: placements=%zu rotated=%zu\n", argv[1], m.placements.size(), rotated);
    std::fprintf(stderr, "[probe] world bounds x[%.1f .. %.1f] y[%.1f .. %.1f] z[%.1f .. %.1f]\n",
                 m.worldMin[0], m.worldMax[0], m.worldMin[1], m.worldMax[1], m.worldMin[2], m.worldMax[2]);

    if (argc >= 4) { // dump the placement nearest the anchor
        const float ax = std::atof(argv[2]), ay = std::atof(argc > 3 ? argv[3] : "0"), az = std::atof(argc > 4 ? argv[4] : "0");
        size_t best = 0; double bd = 1e30;
        for (size_t i = 0; i < m.placements.size(); ++i) {
            const auto& t = m.placements[i].trans;
            const double d2 = (t[0]-ax)*(t[0]-ax) + (t[1]-ay)*(t[1]-ay) + (t[2]-az)*(t[2]-az);
            if (d2 < bd) { bd = d2; best = i; }
        }
        const auto& pl = m.placements[best];
        std::fprintf(stderr, "[probe] nearest placement to (%.2f,%.2f,%.2f): dist=%.3f\n", ax, ay, az, std::sqrt(bd));
        for (int r = 0; r < 3; ++r)
            std::fprintf(stderr, "    row%d: %9.6f %9.6f %9.6f   trans=(%8.4f,%8.4f,%8.4f)\n", r,
                         pl.rot[r*3+0], pl.rot[r*3+1], pl.rot[r*3+2], pl.trans[0], pl.trans[1], pl.trans[2]);
    }
    return 0;
}
