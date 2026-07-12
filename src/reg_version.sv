// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Status register: gateware version (layout: types::version_t), stamped at synth
// time via -D flags from the git tag (mk/version.mk). The `ifndef defaults make it
// elaborate as version 0 when the flags are absent.
`ifndef VERSION_MAJOR
  `define VERSION_MAJOR 0
`endif
`ifndef VERSION_MINOR
  `define VERSION_MINOR 0
`endif
`ifndef VERSION_PATCH
  `define VERSION_PATCH 0
`endif
`ifndef VERSION_GIT_SHA
  `define VERSION_GIT_SHA 0
`endif
`ifndef VERSION_COMMITS
  `define VERSION_COMMITS 0
`endif
`ifndef VERSION_DIRTY
  `define VERSION_DIRTY 0
`endif
module reg_version (
    output types::status_value_t value
);
    types::version_t v;
    assign v = '{
        major:   `VERSION_MAJOR,
        minor:   `VERSION_MINOR,
        patch:   `VERSION_PATCH,
        git_sha: 'h`VERSION_GIT_SHA,
        commits: `VERSION_COMMITS,
        dirty:   `VERSION_DIRTY
    };
    assign value = types::status_value_t'(v);
endmodule
